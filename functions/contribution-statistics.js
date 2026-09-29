const {DateTime} = require('luxon');
const {orgId, millis} = require('./statistics-history');
const ZONE = 'Europe/Tallinn';
const active = d => d && (d.status === 'active' || d.isActive === true) &&
  (d.status === undefined || d.status === 'active') && (d.isActive === undefined || d.isActive === true);
const TYPES = {training:'Koolitus', exercise:'Harjutus', maintenance:'Hooldus', repair:'Remont', groundskeeping:'Heakord / niitmine', meeting:'Koosolek', event:'Sündmus', other:'Muu tegevus'};
function dateMillis(value) {
  if (typeof value !== 'string') return millis(value);
  const date = DateTime.fromISO(value.trim().replace(' ', 'T'), {zone:ZONE});
  return date.isValid ? +date : null;
}
function period(from, to) {
  if(typeof from !== 'string' || typeof to !== 'string') return null;
  const a = DateTime.fromISO(from || '', {zone:ZONE}).startOf('day');
  const b = DateTime.fromISO(to || '', {zone:ZONE}).startOf('day');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from || '') || !/^\d{4}-\d{2}-\d{2}$/.test(to || '') || !a.isValid || !b.isValid || b < a || b.diff(a,'days').days > 365) return null;
  return {start:+a, end:+b.plus({days:1})};
}
function versionTimelines(current, history, trackingStart, now) {
  const timelines = new Map();
  for (const record of current) timelines.set(`${record.source}/${record.id}`, {...record, events:[]});
  for (const event of history) {
    if (event.at < trackingStart) continue;
    const key = `${event.source}/${event.sourceId}`;
    if (!timelines.has(key)) timelines.set(key,{source:event.source, id:event.sourceId, data:null, events:[]});
    timelines.get(key).events.push(event);
  }
  let pending = false;
  for (const line of timelines.values()) {
    line.events.sort((a,b) => a.at-b.at);
    line.initial = line.events.length ? line.events[0].before : line.data;
    if (line.version > trackingStart && !line.events.some(e => e.at === line.version) && line.version <= now) pending = true;
    // A source changed while the report was being read. Wait for its history,
    // rather than apply the newly read state to an older time interval.
    if (line.version > now && !line.events.some(e => e.at === line.version)) pending = true;
  }
  return {lines:[...timelines.values()], pending};
}
function stateAt(line, at) {
  let state = line.initial;
  for (const event of line.events) { if(event.at > at) break; state = event.after; }
  return state;
}
function dutyForMember(uid, lines, start, end, pauses=[]) {
  if (!(end > start)) return {dutyHours:0, delayedHours:0};
  const own = lines.filter(line => [line.initial,line.data,...line.events.flatMap(e=>[e.before,e.after])].some(d=>d?.userId === uid));
  const cuts = new Set([start,end]);
  const add = t => { if(Number.isFinite(t) && t>start && t<end) cuts.add(t); };
  for (const pause of pauses) { add(dateMillis(pause.startAt)); add(dateMillis(pause.endAt)); }
  const ruleVersions = [];
  for (const line of own) {
    line.events.forEach(e=>add(e.at));
    for (const state of [line.initial,...line.events.map(e=>e.after)]) {
      if (!state) continue;
      add(state.joinedAt); add(state.startAt); add(state.endAt);
      if(line.source === 'plannedUnavailabilityRules') ruleVersions.push(state);
    }
  }
  // Calendar boundaries use Tallinn time, including both occurrences of a
  // repeated clock hour. Hour boundaries also cover daylight-saving jumps.
  if (ruleVersions.length) {
    for(let day=DateTime.fromMillis(start,{zone:ZONE}).startOf('day'); +day<end; day=day.plus({days:1})) {
      const next=day.plus({days:1});
      for(let hour=+day;hour<=+next;hour+=3600000) add(hour);
      for(const rule of ruleVersions) for(const minute of [rule.startMinute,rule.endMinute]) {
        if(!Number.isInteger(minute) || minute<0 || minute>1440) continue;
        const boundary=minute===1440?next:day.set({hour:Math.floor(minute/60),minute:minute%60});
        for(const possible of boundary.getPossibleOffsets()) add(+possible);
      }
    }
  }
  const times=[...cuts].sort((a,b)=>a-b);
  let duty=0, delayed=0;
  for(let i=1;i<times.length;i++) {
    const at=(times[i-1]+times[i])/2;
    if (pauses.some(p => dateMillis(p.startAt)!==null && at>=dateMillis(p.startAt) && (p.endAt==null || at<dateMillis(p.endAt)))) continue;
    const states=own.map(line=>({source:line.source,id:line.id,data:stateAt(line,at)})).filter(r=>r.data?.userId===uid);
    // Canonical membership takes precedence over any legacy duplicate.
    const memberships=states.filter(r=>r.source==='memberships');
    const canonical=memberships.find(r=>r.id===`${uid}_${r.data.organizationId}`);
    const membership=canonical?.data || memberships[0]?.data;
    if(!active(membership) || (membership.joinedAt && at<membership.joinedAt)) continue;
    const availability=states.filter(r=>r.source==='availability');
    const manual=availability.find(r=>r.id===`${uid}_${r.data.organizationId}`)?.data || availability[0]?.data;
    if(!['onDuty','delayed'].includes(manual?.status)) continue;
    const clock=DateTime.fromMillis(at,{zone:ZONE});
    const minute=clock.hour*60+clock.minute;
    const unavailable=states.some(({source,data:d}) => d.status==='active' &&
      ((source==='plannedUnavailability' && Number.isFinite(d.startAt) && Number.isFinite(d.endAt) && at>=d.startAt && at<d.endAt) ||
       (source==='plannedUnavailabilityRules' && d.daysOfWeek?.includes(clock.weekday) && minute>=d.startMinute && minute<d.endMinute)));
    if(unavailable) continue;
    if(manual.status==='onDuty') duty+=times[i]-times[i-1]; else delayed+=times[i]-times[i-1];
  }
  return {dutyHours:duty/3600000, delayedHours:delayed/3600000};
}
function aggregate({organizationId, from, to, now, trackingStart, current, history, memberships, activities, participants, callouts, responses, attendance, dutyPauses=[]}) {
  const range=period(from,to);
  if(!range) throw Error('Invalid period');
  const end=Math.min(range.end,now), start=range.start;
  const scoped=list=>list.filter(d=>orgId(d)===organizationId);
  current=current.filter(r=>orgId(r.data)===organizationId);
  history=history.filter(r=>r.organizationId===organizationId);
  const timeline=versionTimelines(current,history,trackingStart,now);
  const rows=new Map();
  const member=(uid,name)=> {
    if(!rows.has(uid)) rows.set(uid,{userId:uid,name:name||'Liige',active:false,dutyHours:0,delayedHours:0,calloutCount:0,responseCount:0,activityCount:0,contributionHours:0,pendingCount:0,unknownHoursCount:0,categories:{},entries:[]});
    const row=rows.get(uid); if(name && row.name==='Liige') row.name=name; return row;
  };
  for(const m of scoped(memberships).sort((a,b)=>Number(a.id===`${a.userId}_${organizationId}`)-Number(b.id===`${b.userId}_${organizationId}`))) { const row=member(m.userId,m.displayName); row.active=active(m); }
  for(const h of history) if(h.userId) member(h.userId,h.after?.displayName || h.before?.displayName);
  const byActivity=new Map(scoped(activities).map(a=>[a.id,a]));
  const byCallout=new Map(scoped(callouts).filter(c=>c.isTest!==true).map(c=>[c.id,c]));
  let undatedCount=0;
  const seen=new Set();
  for(const p of scoped(participants)) {
    const a=byActivity.get(p.activityId);
    if(!a || !p.userId) continue;
    const at=dateMillis(a.startTime);
    if(at===null) { undatedCount++; continue; }
    if(at<start || at>=end || p.attendanceStatus==='absent') continue;
    const confirmed=p.attendanceStatus==='confirmed';
    if(!confirmed && !['attending','registered','attendedSelfReported'].includes(p.status)) continue;
    const key=`activity:${a.id}:${p.userId}`; if(seen.has(key)) continue; seen.add(key);
    const row=member(p.userId); const type=Object.hasOwn(TYPES,a.type)?a.type:'other';
    const hours=typeof p.hours==='number' && Number.isFinite(p.hours) && p.hours>=0 ? p.hours : null;
    row.entries.push({id:a.id,kind:'activity',title:a.title||'Tegevus',category:type,date:new Date(at).toISOString(),hours,confirmed});
    if(!confirmed) {row.pendingCount++;continue;}
    row.activityCount++; row.contributionHours+=hours||0; if(hours===null) row.unknownHoursCount++;
    const category=row.categories[type] ||= {count:0,hours:0}; category.count++; category.hours+=hours||0;
  }
  for(const p of scoped(attendance)) {
    const c=byCallout.get(p.calloutId); const at=dateMillis(c?.startedAt || c?.createdAt);
    if(!c || !p.userId || p.status!=='confirmed' || c.status==='cancelled' || at===null || at<start || at>=end) continue;
    const key=`callout:${c.id}:${p.userId}`;if(seen.has(key))continue;seen.add(key);
    const row=member(p.userId,p.userName); const hours=typeof p.hours==='number' && Number.isFinite(p.hours) && p.hours>=0?p.hours:null;
    row.calloutCount++;row.contributionHours+=hours||0;if(hours===null)row.unknownHoursCount++;
    row.entries.push({id:c.id,kind:'callout',title:c.title||'Väljakutse',category:'callout',date:new Date(at).toISOString(),hours,confirmed:true});
  }
  for(const r of scoped(responses)) {
    const c=byCallout.get(r.calloutId),at=dateMillis(c?.startedAt || c?.createdAt);
    if(!c || !r.userId || c.status==='cancelled' || !['responding','delayed'].includes(r.response) || at===null || at<start || at>=end)continue;
    const key=`response:${c.id}:${r.userId}`;if(seen.has(key))continue;seen.add(key);member(r.userId,r.userName).responseCount++;
  }
  const covered=Number.isFinite(trackingStart) && end>Math.max(start,trackingStart) && !timeline.pending;
  for(const row of rows.values()) {
    if(covered) Object.assign(row,dutyForMember(row.userId,timeline.lines,Math.max(start,trackingStart),end,scoped(dutyPauses)));
    else {row.dutyHours=null;row.delayedHours=null;}
    row.entries.sort((a,b)=>b.date.localeCompare(a.date));
  }
  const members=[...rows.values()].filter(r=>r.active || r.entries.length || r.responseCount || r.dutyHours>0 || r.delayedHours>0).sort((a,b)=>a.name.localeCompare(b.name,'et'));
  const periodCallouts=[...byCallout.values()].filter(c=>{const at=dateMillis(c.startedAt || c.createdAt);return at!==null && at>=start && at<end;});
  const events={total:byCallout.size,period:periodCallouts.length,
    sar:periodCallouts.filter(c=>(c.calloutType || 'sar')==='sar').length,
    tross:periodCallouts.filter(c=>c.calloutType==='tross').length,
    closed:periodCallouts.filter(c=>c.status==='closed').length,
    cancelled:periodCallouts.filter(c=>c.status==='cancelled').length,
    undated:[...byCallout.values()].filter(c=>dateMillis(c.startedAt || c.createdAt)===null).length};
  return {events,from,to,generatedAt:new Date(now).toISOString(),trackingStartedAt:Number.isFinite(trackingStart)?new Date(trackingStart).toISOString():null,
    dutyHistoryPending:timeline.pending,undatedCount,members};
}
module.exports={ZONE,TYPES,active,dateMillis,period,dutyForMember,versionTimelines,aggregate};

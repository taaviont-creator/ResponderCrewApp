// Synthetic fixtures only: never connects to Firebase or modifies real organizations.
const fs=require('node:fs');
const path=require('node:path');
const {evaluateReadiness}=require('../functions/effective-readiness');
const {evaluateCenterReadiness}=require('../functions/center-readiness');
const specs=[
  ['north','Näidis · Põhjarannik',59.45,26.5,'normal'],
  ['west','Näidis · Läänerannik',58.39,24.5,'one'],
  ['island','Näidis · Saare baas',58.25,22.45,'delay'],
  ['east','Näidis · Idarannik',59.4,27.6,'paused'],
  ['unknown','Näidis · Kontrollimata',58.95,23.55,'unknown'],
  ['missing','Näidis · Asukoht lisamata',null,null,'normal'],
  ['broken','Näidis · Remondis alus',59.42,24.7,'broken'],
];
const cases={};
for(const scenario of ['normal','absence','delay','paused','broken','expired']) {
  cases[scenario]={};
  for(const service of ['sar','tross']) {
    cases[scenario][service]=specs.map(([id,name,latitude,longitude,original])=>{
      const mode=id==='north'?scenario:original,now=0;
      const users=['a','b','c'];
      const members=users.map((userId,i)=>({id:`${userId}_${id}`,organizationId:id,userId,status:'active',isActive:true,displayName:`Prooviliige ${i+1}`,seaRescueLevel:i===2?'level2':'level1'}));
      const availability=users.map((userId,i)=>({id:`${userId}_${id}`,organizationId:id,userId,status:mode==='delay'?'delayed':mode==='one' && i>0?'offDuty':'onDuty',responseMinutes:30}));
      const r=evaluateReadiness({org:id,organization:{status:'approved',dutyPaused:mode==='paused'},settings:{minimumCrewRequired:3},
        members,availability,periods:mode==='absence'?[{organizationId:id,userId:'c',status:'active',startAt:new Date(-60000),endAt:new Date(3600000)}]:[],rules:[],now});
      const vessels=[{name:'Näidispaat',status:mode==='broken'?'broken':'ok'}];
      const summary=evaluateCenterReadiness({service,readiness:r,policy:{enabled:true,minimumResponders:1,departureMinutes:service==='sar'?15:60},vessels,now,
        evidenceReady:mode!=='unknown',revision:1,confirmation:{revision:1,confirmedAtMs:-60000,validUntilMs:mode==='expired'?-1:14400000,...(mode==='delay'?{expectedReadyAtMs:1800000}:{})}});
      return {id,name,latitude,longitude,vessels,contactName:'Näidiskontakt',contactPhone:'',...summary};
    });
  }
}
const target=path.join(__dirname,'../assets/center-demo.json');
fs.writeFileSync(target,JSON.stringify(cases,null,2)+'\n');
console.log('Generated synthetic center demo scenarios.');

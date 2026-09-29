// Small Firestore double for external delivery tests. Permission/transaction
// behavior is covered separately against the actual Firestore emulator.
function memoryDb(initial = {}) {
  const records = new Map(Object.entries(initial).filter(([,v])=>v!=null));
  const doc = path => ({path,id:path.split('/').at(-1),
    get:async()=>({id:path.split('/').at(-1),ref:doc(path),exists:records.has(path),data:()=>records.get(path)}),
    create:async value=>{if(records.has(path))throw Object.assign(Error('exists'),{code:6});records.set(path,value);},
    update:async value=>records.set(path,{...records.get(path),...value}),
    collection:name=>({doc:id=>doc(`${path}/${name}/${id}`)}),
  });
  const collection = name => {
    const query = filters => ({doc:id=>doc(`${name}/${id}`),where:(field,op,value)=>query([...filters,{field,op,value}]),
      get:async()=>({docs:await Promise.all([...records].filter(([path,d]) => path.split('/').length===2 && path.startsWith(`${name}/`) &&
        filters.every(f=>f.op==='in'?f.value.includes(d[f.field]):d[f.field]===f.value)).map(([path])=>doc(path).get()))}),
    });
    return query([]);
  };
  return {db:{doc,collection},records};
}
module.exports = {memoryDb};

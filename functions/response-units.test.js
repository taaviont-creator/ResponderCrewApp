const {test}=require('node:test');
const assert=require('node:assert/strict');
const {coordinates,key}=require('./response-units');
test('base coordinates are either absent or a complete finite WGS84 pair',()=>{
  assert.equal(coordinates(null,null),null);
  assert.deepEqual(coordinates(59.45,26.5),{latitude:59.45,longitude:26.5});
  for(const pair of [[59,null],[null,26],['59',26],[NaN,26],[Infinity,26],[91,26],[59,181]]) {
    assert.throws(()=>coordinates(...pair),{code:'invalid-argument'});
  }
});
test('reservation keys distinguish types and cannot collide through separators',()=>{
  assert.notEqual(key('member','x'),key('vessel','x'));
  assert.equal(key('member','same-user'),key('member','same-user'));
  assert.notEqual(key('link',JSON.stringify(['a_b','c'])),key('link',JSON.stringify(['a','b_c'])));
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {validateNationalAircraftRegistration as validate,VERIFIED_REGISTRY_COUNTRIES} from '../server/aircraft-registration-policy.mjs';
test('ordinary civil registry marks follow country-specific sourced formats',()=>{
 for(const [country,mark] of [['RS','YU-ALX'],['GB','G-ABCD'],['US','N123AB'],['US','N12345'],['CA','C-FABC'],['CA','C-GXYZ']])
  assert.equal(validate(country,mark).valid,true,mark);
 for(const [country,mark] of [['RS','YU-PAN01'],['RS','YU-PAN'],['RS','YU-SOS'],['RS','YU-QAB'],['RS','YU-ABCD'],['GB','G-PANA'],['GB','G-AQQA'],['GB','G-AZCA'],['GB','G-1234'],['US','N01Z'],['US','N99'],['US','N123IO'],['US','N1234AB'],['US','N-123AB'],['CA','C-IABC'],['CA','YU-ALX']])
  assert.equal(validate(country,mark).valid,false,mark);
 assert.equal(validate('rs',' yu-alx ').registration,'YU-ALX');
});
test('unresearched countries are explicitly not validated; never use a generic invented mark',()=>{
 assert.equal(validate('ZZ','ZZ-ABC').status,'country_rule_not_verified');
 assert.equal(validate('__proto__','ABC').valid,false);
 assert.deepEqual(VERIFIED_REGISTRY_COUNTRIES,['RS','GB','US','CA']);
});

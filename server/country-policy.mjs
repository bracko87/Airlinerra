/** Country grouping for the airline selector, not a statement about sovereignty.
 * Only UN members plus the two UN observer states appear as selectable entries.
 * Territory airports remain in the approved roster and are grouped with their
 * administrating/parent country for the game's country selector.
 */
export const TERRITORY_COUNTRY=Object.freeze({
 AI:'GB',AS:'US',AW:'NL',AX:'FI',BL:'FR',BM:'GB',BQ:'NL',BV:'NO',CC:'AU',
 CK:'NZ',CW:'NL',CX:'AU',EH:'MA',FK:'GB',FO:'DK',
 GF:'FR',GG:'GB',GI:'GB',GL:'DK',GP:'FR',GU:'US',
 GS:'GB',HK:'CN',HM:'AU',IM:'GB',IO:'GB',JE:'GB',KY:'GB',MF:'FR',MO:'CN',MP:'US',
 MQ:'FR',MS:'GB',NC:'FR',NF:'AU',NU:'NZ',PF:'FR',PM:'FR',PN:'GB',
 PR:'US',RE:'FR',SH:'GB',SJ:'NO',SX:'NL',TC:'GB',TF:'FR',TK:'NZ',
 TW:'CN',UM:'US',VG:'GB',VI:'US',WF:'FR',
 XK:'RS',YT:'FR'
});
// 193 UN member countries plus Holy See (VA) and Palestine (PS).
export const UN_COUNTRY_CODES=Object.freeze((
 'AF AL DZ AD AO AG AR AM AU AT AZ BS BH BD BB BY BE BZ BJ BT BO BA BW BR BN BG BF BI CV KH CM CA CF TD CL CN CO KM CG CD CR CI HR CU CY CZ DK DJ DM DO EC EG SV GQ ER EE SZ ET FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT HN HU IS IN ID IR IQ IE IL IT JM JP JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MG MW MY MV ML MT MH MR MU MX FM MD MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PA PA PG PY PE PH PL PT QA RO RU RW KN LC VC WS SM ST SA SN RS SC SL SG SK SI SB SO ZA SS ES LK SD SR SE CH SY TJ TZ TH TL TG TO TT TN TR TM TV UG UA AE GB US UY UZ VU VE VN YE ZM ZW VA PS'
).split(' ').filter((value,index,list)=>list.indexOf(value)===index));
export const UN_COUNTRY_SET=new Set(UN_COUNTRY_CODES);
export function parentCountryIso(code){
 const normalized=TERRITORY_COUNTRY[code]||code;
 return UN_COUNTRY_SET.has(normalized)?normalized:null;
}
export function countrySqlExpression(column='country_iso'){
 if(!/^[a-z_]+$/i.test(column))throw Error('Invalid country SQL column');
 const cases=Object.entries(TERRITORY_COUNTRY).map(([territory,parent])=>
  "when '"+territory+"' then '"+parent+"'").join(' ');
 return 'case '+column+' '+cases+' else '+column+' end';
}

# Airlinerra World 1 — Identity & Geography: Complete Missing-Data Register

**Audit date:** 29 October 2026. **Approved airports checked:** 3,141. Database: `airlinerra_game.airport_reference_profiles` and `airport_identity_geography_audit`.

**Interpretation:** “Not reported” does **not** mean the airport definitively has no IATA/ICAO/local code. Source-reported values are not independently verified. Real airport coordinates are source reported. The single fictional airport has no approved physical airfield coordinates. Time-zone matches are **unverified candidates** and must not be used to activate flight scheduling. Official names are display/source names pending independent authority verification.

**Full 3,141-row report:** [`world1_3141_identity_geography_audit_20261029.csv`](world1_3141_identity_geography_audit_20261029.csv). It contains the code columns, city, region, lat/lon, time-zone candidate, elevation candidate, provenance statuses and missing/pending field list for every airport.

| Field | Source-reported / candidate | Not reported / unresolved |
|---|---:|---:|
| Display name | 3,141 | 0 |
| Game code | 3,141 | 0 |
| Source ident | 3,141 | 0 |
| ICAO | 3,125 | 16 |
| IATA | 3,111 | 30 |
| GPS | 3,134 | 7 |
| Local code (often legitimately unavailable) | 822 | 2,319 |
| Country | 3,141 | 0 |
| Municipality | 3,089 | 52 |
| Region | 3,140 | 1 |
| Latitude/longitude | 3,140 | 1 |
| Time-zone candidates (not verified) | 3,020 | 121 |
| Elevations (source-reported) | 3,119 | 22 |

**All official-name reviews remain pending** (3,141/3,141); that is a verification task, not proof that the source display names are incorrect. The source-country and World 1 grouped country are separate columns.

## ICAO identifier not reported — 16

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Aeródromo Estancia Don Panos | `OURAIRPORTS:20` | AR | ICAO — · IATA — · GPS SA10 |
| La Romaine Airport | `OURAIRPORTS:1617` | CA | ICAO — · IATA ZGS · GPS CTT5 |
| Streatham Reef Hueston Airfield | `OURAIRPORTS:355458` | CA | ICAO — · IATA — · GPS CRHA |
| Trail Regional Airport | `OURAIRPORTS:614` | CA | ICAO — · IATA YZZ · GPS CAD4 |
| Old Nabire Airport | `OURAIRPORTS:26747` | ID | ICAO — · IATA — · GPS — |
| Tabing Airport | `OURAIRPORTS:26838` | ID | ICAO — · IATA — · GPS — |
| Camaguey-Campo Cuatro Milpas Airport | `OURAIRPORTS:4897` | MX | ICAO — · IATA — · GPS — |
| Cedros Airport | `OURAIRPORTS:319370` | MX | ICAO — · IATA — · GPS — |
| Aleksandrovo Airport | `FICTIONAL:fictional:RS:LYAL` | RS | ICAO — · IATA — · GPS LYAL |
| Kirovsk-Apatity Airport | `OURAIRPORTS:35001` | RU | ICAO — · IATA KVK · GPS XLMK |
| Motygino Airport | `OURAIRPORTS:323478` | RU | ICAO — · IATA MJY · GPS UNIM |
| Nogliki Airport | `OURAIRPORTS:41838` | RU | ICAO — · IATA NGK · GPS UHSN |
| Solovki Airport | `OURAIRPORTS:42918` | RU | ICAO — · IATA CSH · GPS ULAS |
| Srednekolymsk Airport | `OURAIRPORTS:316761` | RU | ICAO — · IATA SEK · GPS UESK |
| Lajitas International Airport | `OURAIRPORTS:14843` | US | ICAO — · IATA — · GPS KT89 |
| Roche Harbor Airport | `OURAIRPORTS:25606` | US | ICAO — · IATA RCE · GPS WA09 |

## IATA identifier not reported — 30

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Aeródromo Estancia Don Panos | `OURAIRPORTS:20` | AR | ICAO — · IATA — · GPS SA10 |
| Pitt Meadows Regional Airport | `OURAIRPORTS:1848` | CA | ICAO CYPK · IATA — · GPS CYPK |
| Streatham Reef Hueston Airfield | `OURAIRPORTS:355458` | CA | ICAO — · IATA — · GPS CRHA |
| Las Marías Airport | `OURAIRPORTS:6049` | CL | ICAO SCVL · IATA — · GPS SCVL |
| Ho Airport | `OURAIRPORTS:354173` | GH | ICAO DGAH · IATA — · GPS DGAH |
| Győr-Pér Airport | `OURAIRPORTS:4303` | HU | ICAO LHPR · IATA — · GPS LHPR |
| Old Nabire Airport | `OURAIRPORTS:26747` | ID | ICAO — · IATA — · GPS — |
| Tabing Airport | `OURAIRPORTS:26838` | ID | ICAO — · IATA — · GPS — |
| Batken Airport | `OURAIRPORTS:3549` | KG | ICAO UCFB · IATA — · GPS UCFB |
| Jalal-Abad Airport | `OURAIRPORTS:41534` | KG | ICAO UCFD · IATA — · GPS UCFD |
| Kyzyl-Kiya Airport | `OURAIRPORTS:41657` | KG | ICAO UAFS · IATA — · GPS UAFS |
| Naryn Airport | `OURAIRPORTS:41535` | KG | ICAO UCFN · IATA — · GPS UAFN |
| Talas Airport | `OURAIRPORTS:41537` | KG | ICAO UAFT · IATA — · GPS UAFT |
| Camaguey-Campo Cuatro Milpas Airport | `OURAIRPORTS:4897` | MX | ICAO — · IATA — · GPS — |
| Cedros Airport | `OURAIRPORTS:319370` | MX | ICAO — · IATA — · GPS — |
| Isla Cedros Airport | `OURAIRPORTS:4864` | MX | ICAO MMCD · IATA — · GPS MMCD |
| Twyfelfontein Airport | `OURAIRPORTS:595415` | NA | ICAO FYTF · IATA — · GPS FYTF |
| Bayelsa International Airport | `OURAIRPORTS:340295` | NG | ICAO DNBY · IATA — · GPS DNBY |
| Sir Ahmadu Bello International Airport | `OURAIRPORTS:313797` | NG | ICAO DNBK · IATA — · GPS DNBK |
| Aleksandrovo Airport | `FICTIONAL:fictional:RS:LYAL` | RS | ICAO — · IATA — · GPS LYAL |
| Ust'-Kamchatsk Airport | `OURAIRPORTS:32519` | RU | ICAO UHPK · IATA — · GPS UHPK |
| Alphonse Airport | `OURAIRPORTS:2990` | SC | ICAO FSAL · IATA — · GPS FSAL |
| Pingtung Air Force Base North | `OURAIRPORTS:5526` | TW | ICAO RCSQ · IATA — · GPS RCSQ |
| Arlington Municipal Airport | `OURAIRPORTS:19334` | US | ICAO KAWO · IATA — · GPS KAWO |
| Austin Executive Airport | `OURAIRPORTS:45955` | US | ICAO KEDC · IATA — · GPS KEDC |
| Beaver Island Airport | `OURAIRPORTS:21074` | US | ICAO KSJX · IATA — · GPS KSJX |
| Charlevoix Municipal Airport | `OURAIRPORTS:19570` | US | ICAO KCVX · IATA — · GPS KCVX |
| Erie-Ottawa International Airport | `OURAIRPORTS:20812` | US | ICAO KPCW · IATA — · GPS KPCW |
| Lajitas International Airport | `OURAIRPORTS:14843` | US | ICAO — · IATA — · GPS KT89 |
| Pietersburg Municipal Airport | `OURAIRPORTS:2823` | ZA | ICAO FAPI · IATA — · GPS FAPI |

## GPS identifier not reported — 7

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Old Nabire Airport | `OURAIRPORTS:26747` | ID | ICAO — · IATA — · GPS — |
| Tabing Airport | `OURAIRPORTS:26838` | ID | ICAO — · IATA — · GPS — |
| Maa Mahamaya Airport | `OURAIRPORTS:598586` | IN | ICAO VEAP · IATA AHA · GPS — |
| Camaguey-Campo Cuatro Milpas Airport | `OURAIRPORTS:4897` | MX | ICAO — · IATA — · GPS — |
| Cedros Airport | `OURAIRPORTS:319370` | MX | ICAO — · IATA — · GPS — |
| Santa Elena de Uairén Airport | `OURAIRPORTS:6323` | VE | ICAO SVSE · IATA SNV · GPS — |
| Eastgate Airport / Air Force Base Hoedspruit | `OURAIRPORTS:29953` | ZA | ICAO FAHS · IATA HDS · GPS — |

## Municipality not reported — 52

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Bendigo Airport | `OURAIRPORTS:26906` | AU | ICAO YBDG · IATA BXG · GPS YBDG |
| Birdsville Airport | `OURAIRPORTS:26907` | AU | ICAO YBDV · IATA BVI · GPS YBDV |
| Boulia Airport | `OURAIRPORTS:26923` | AU | ICAO YBOU · IATA BQL · GPS YBOU |
| Bourke Airport | `OURAIRPORTS:26912` | AU | ICAO YBKE · IATA BRK · GPS YBKE |
| Burketown Airport | `OURAIRPORTS:26913` | AU | ICAO YBKT · IATA BUC · GPS YBKT |
| Ceduna Airport | `OURAIRPORTS:26950` | AU | ICAO YCDU · IATA CED · GPS YCDU |
| Cobar Airport | `OURAIRPORTS:26943` | AU | ICAO YCBA · IATA CAZ · GPS YCBA |
| Cooktown Airport | `OURAIRPORTS:26955` | AU | ICAO YCKN · IATA CTN · GPS YCKN |
| Coonamble Airport | `OURAIRPORTS:26959` | AU | ICAO YCNM · IATA CNB · GPS YCNM |
| Cunnamulla Airport | `OURAIRPORTS:26957` | AU | ICAO YCMU · IATA CMA · GPS YCMU |
| Doomadgee Airport | `OURAIRPORTS:26973` | AU | ICAO YDMG · IATA DMD · GPS YDMG |
| Fitzroy Crossing Airport | `OURAIRPORTS:26986` | AU | ICAO YFTZ · IATA FIZ · GPS YFTZ |
| Julia Creek Airport | `OURAIRPORTS:27020` | AU | ICAO YJLC · IATA JCK · GPS YJLC |
| Kalkgurung Airport | `OURAIRPORTS:27024` | AU | ICAO YKKG · IATA KFG · GPS YKKG |
| King Island Airport | `OURAIRPORTS:27023` | AU | ICAO YKII · IATA KNS · GPS YKII |
| Kingscote Airport | `OURAIRPORTS:27028` | AU | ICAO YKSC · IATA KGC · GPS YKSC |
| Leinster Airport | `OURAIRPORTS:27039` | AU | ICAO YLST · IATA LER · GPS YLST |
| Lightning Ridge Airport | `OURAIRPORTS:27037` | AU | ICAO YLRD · IATA LHG · GPS YLRD |
| Meekatharra Airport | `OURAIRPORTS:27050` | AU | ICAO YMEK · IATA MKR · GPS YMEK |
| Oakey Army Aviation Centre | `OURAIRPORTS:26922` | AU | ICAO YBOK · IATA OKY · GPS YBOK |
| Port Augusta Airport | `OURAIRPORTS:27097` | AU | ICAO YPAG · IATA PUG · GPS YPAG |
| Portland Airport | `OURAIRPORTS:27116` | AU | ICAO YPOD · IATA PTJ · GPS YPOD |
| Richmond Airport | `OURAIRPORTS:27126` | AU | ICAO YRMD · IATA RCM · GPS YRMD |
| St George Airport | `OURAIRPORTS:27136` | AU | ICAO YSGE · IATA SGO · GPS YSGE |
| Walgett Airport | `OURAIRPORTS:27174` | AU | ICAO YWLG · IATA WGE · GPS YWLG |
| Wiluna Airport | `OURAIRPORTS:27176` | AU | ICAO YWLU · IATA WUN · GPS YWLU |
| Winton Airport | `OURAIRPORTS:27180` | AU | ICAO YWTN · IATA WIN · GPS YWTN |
| San Pedro Airport | `OURAIRPORTS:2101` | CI | ICAO DISP · IATA SPY · GPS DISP |
| Jaisalmer Airport | `OURAIRPORTS:26564` | IN | ICAO VIJR · IATA JSA · GPS VIJR |
| Jharsuguda Airport | `OURAIRPORTS:26505` | IN | ICAO VEJH · IATA JRG · GPS VEJH |
| Tezpur Airport | `OURAIRPORTS:26521` | IN | ICAO VETZ · IATA TEZ · GPS VETZ |
| Khoram Abad Airport | `OURAIRPORTS:5151` | IR | ICAO OICK · IATA KHD · GPS OICK |
| Sanandaj Airport | `OURAIRPORTS:5152` | IR | ICAO OICS · IATA SDG · GPS OICS |
| Choibalsan Airport | `OURAIRPORTS:27208` | MN | ICAO ZMCD · IATA COQ · GPS ZMCD |
| Hokitika Airfield | `OURAIRPORTS:5032` | NZ | ICAO NZHK · IATA HKK · GPS NZHK |
| Timaru Airport | `OURAIRPORTS:5056` | NZ | ICAO NZTU · IATA TIU · GPS NZTU |
| Arutua Airport | `OURAIRPORTS:4994` | PF | ICAO NTGU · IATA AXR · GPS NTGU |
| Fakarava Airport | `OURAIRPORTS:4987` | PF | ICAO NTGF · IATA FAV · GPS NTGF |
| Raivavae Airport | `OURAIRPORTS:4982` | PF | ICAO NTAV · IATA RVV · GPS NTAV |
| Rangiroa Airport | `OURAIRPORTS:5004` | PF | ICAO NTTG · IATA RGI · GPS NTTG |
| Rurutu Airport | `OURAIRPORTS:4980` | PF | ICAO NTAR · IATA RUR · GPS NTAR |
| Totegegie Airport | `OURAIRPORTS:4989` | PF | ICAO NTGJ · IATA GMR · GPS NTGJ |
| Tubuai Airport | `OURAIRPORTS:4981` | PF | ICAO NTAT · IATA TUB · GPS NTAT |
| Beloyarskiy Airport | `OURAIRPORTS:43692` | RU | ICAO USHQ · IATA EYK · GPS USHQ |
| Lampang Airport | `OURAIRPORTS:26649` | TH | ICAO VTCL · IATA LPT · GPS VTCL |
| Loei Airport | `OURAIRPORTS:26682` | TH | ICAO VTUL · IATA LOE · GPS VTUL |
| Mae Sot Airport | `OURAIRPORTS:26658` | TH | ICAO VTPM · IATA MAQ · GPS VTPM |
| Nan Airport | `OURAIRPORTS:26650` | TH | ICAO VTCN · IATA NNT · GPS VTCN |
| Narathiwat Airport | `OURAIRPORTS:26666` | TH | ICAO VTSC · IATA NAW · GPS VTSC |
| Phetchabun Airport | `OURAIRPORTS:26654` | TH | ICAO VTPB · IATA PHY · GPS VTPB |
| Sakon Nakhon Airport | `OURAIRPORTS:26679` | TH | ICAO VTUI · IATA SNO · GPS VTUI |
| Sukhothai Airport | `OURAIRPORTS:26660` | TH | ICAO VTPO · IATA THS · GPS VTPO |

## Region not reported — 1

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Aleksandrovo Airport | `FICTIONAL:fictional:RS:LYAL` | RS | ICAO — · IATA — · GPS LYAL |

## Airport coordinates unavailable — 1

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Aleksandrovo Airport | `FICTIONAL:fictional:RS:LYAL` | RS | ICAO — · IATA — · GPS LYAL |

## IANA time-zone candidate unresolved — 121

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Khost International Airport | `OURAIRPORTS:332240` | AF | ICAO OAKS · IATA KHT · GPS OAKS |
| Burton-Nibbs International Airport | `OURAIRPORTS:336537` | AG | ICAO TAPB · IATA BBQ · GPS TAPB |
| Aeródromo Estancia Don Panos | `OURAIRPORTS:20` | AR | ICAO — · IATA — · GPS SA10 |
| Karara Airport | `OURAIRPORTS:354528` | AU | ICAO YKAR · IATA KQR · GPS YKAR |
| Thangool Airport | `OURAIRPORTS:27158` | AU | ICAO YTNG · IATA THG · GPS YTNG |
| Antwerp International Airport (Deurne) | `OURAIRPORTS:2152` | BE | ICAO EBAW · IATA ANR · GPS EBAW |
| Brussels Airport | `OURAIRPORTS:2155` | BE | ICAO EBBR · IATA BRU · GPS EBBR |
| Brussels South Charleroi Airport | `OURAIRPORTS:2157` | BE | ICAO EBCI · IATA CRL · GPS EBCI |
| Liège Airport | `OURAIRPORTS:2162` | BE | ICAO EBLG · IATA LGG · GPS EBLG |
| Ostend-Bruges International Airport | `OURAIRPORTS:2163` | BE | ICAO EBOS · IATA OST · GPS EBOS |
| Chimore Airport | `OURAIRPORTS:6181` | BO | ICAO SLHI · IATA CCA · GPS SLHI |
| Adolino Bedin Regional Airport | `OURAIRPORTS:321014` | BR | ICAO SBSO · IATA SMT · GPS SBSO |
| Guaíra Airport | `OURAIRPORTS:460` | BR | ICAO SSGY · IATA GGJ · GPS SSGY |
| Pedro Vieira Moreira Airport | `OURAIRPORTS:323824` | BR | ICAO SJZA · IATA CJZ · GPS SJZA |
| Congo Town Airport | `OURAIRPORTS:4926` | BS | ICAO MYAK · IATA TZN · GPS MYAK |
| La Romaine Airport | `OURAIRPORTS:1617` | CA | ICAO — · IATA ZGS · GPS CTT5 |
| Streatham Reef Hueston Airfield | `OURAIRPORTS:355458` | CA | ICAO — · IATA — · GPS CRHA |
| Burqin Kanas Airport | `OURAIRPORTS:313426` | CN | ICAO ZWKN · IATA KJI · GPS ZWKN |
| Cangyuan Washan Airport | `OURAIRPORTS:327447` | CN | ICAO ZPCW · IATA CWJ · GPS ZPCW |
| Chizhou Jiuhuashan Airport | `OURAIRPORTS:308641` | CN | ICAO ZSJH · IATA JUH · GPS ZSJH |
| Daxing'anling Elunchun Airport | `OURAIRPORTS:301009` | CN | ICAO ZYJD · IATA JGD · GPS ZYJD |
| Golog Maqên Airport | `OURAIRPORTS:319715` | CN | ICAO ZLGL · IATA GMQ · GPS ZLGL |
| Hechi Jinchengjiang Airport | `OURAIRPORTS:318152` | CN | ICAO ZGHC · IATA HCJ · GPS ZGHC |
| Jiansanjiang Shidi Airport | `OURAIRPORTS:327450` | CN | ICAO ZYJS · IATA JSJ · GPS ZYJS |
| Jieyang Chaoshan International Airport | `OURAIRPORTS:32400` | CN | ICAO ZGOW · IATA SWA · GPS ZGOW |
| Jingzhou Shashi Airport | `OURAIRPORTS:347636` | CN | ICAO ZHJZ · IATA SHS · GPS ZHJZ |
| Kunming Changshui International Airport | `OURAIRPORTS:27214` | CN | ICAO ZPPP · IATA KMG · GPS ZPPP |
| Kuqa Qiuci Airport | `OURAIRPORTS:31731` | CN | ICAO ZWKC · IATA KCA · GPS ZWKC |
| Meizhou Meixian Changgangji International Airport | `OURAIRPORTS:35314` | CN | ICAO ZGMX · IATA MXZ · GPS ZGMX |
| Ninglang Luguhu Airport | `OURAIRPORTS:316547` | CN | ICAO ZPNL · IATA NLH · GPS ZPNL |
| Xigaze Peace Airport / Shigatse Air Base | `OURAIRPORTS:44122` | CN | ICAO ZURK · IATA RKZ · GPS ZURK |
| Xinyuan Nalati Airport | `OURAIRPORTS:316548` | CN | ICAO ZWNL · IATA NLT · GPS ZWNL |
| Yulin Yuyang Airport | `OURAIRPORTS:32563` | CN | ICAO ZLYL · IATA UYN · GPS ZLYL |
| Zhangjiakou Ningyuan Airport | `OURAIRPORTS:44100` | CN | ICAO ZBZJ · IATA ZQZ · GPS ZBZJ |
| Alexandria International Airport | `OURAIRPORTS:3180` | EG | ICAO HEAX · IATA HBE · GPS HEAX |
| Hawassa International Airport | `OURAIRPORTS:30664` | ET | ICAO HALA · IATA AWA · GPS HALA |
| Semera Airport | `OURAIRPORTS:314658` | ET | ICAO HASM · IATA SZE · GPS HASM |
| Gamba Airport | `OURAIRPORTS:35322` | GA | ICAO FOGX · IATA GAX · GPS FOGX |
| Ho Airport | `OURAIRPORTS:354173` | GH | ICAO DGAH · IATA — · GPS DGAH |
| Annobón Airport | `OURAIRPORTS:313672` | GQ | ICAO FGAN · IATA NBN · GPS FGAN |
| Corisco International Airport | `OURAIRPORTS:316826` | GQ | ICAO FGCO · IATA OCS · GPS FGCO |
| President Obiang Nguema International Airport | `OURAIRPORTS:318497` | GQ | ICAO FGMY · IATA GEM · GPS FGMY |
| Mundo Maya International Airport | `OURAIRPORTS:4649` | GT | ICAO MGMM · IATA FRS · GPS MGMM |
| Alas Leuser Airport | `OURAIRPORTS:507992` | ID | ICAO WIMU · IATA LSR · GPS WIMU |
| Banyuwangi Airport | `OURAIRPORTS:46587` | ID | ICAO WADY · IATA BWX · GPS WADY |
| Bolaang Mongondow Airport | `OURAIRPORTS:526307` | ID | ICAO WAMI · IATA LKM · GPS WAMI |
| Bua - Palopo Lagaligo Airport | `OURAIRPORTS:331735` | ID | ICAO WAFD · IATA LLO · GPS WAFD |
| David Constantijn Saudale Airport | `OURAIRPORTS:41481` | ID | ICAO WATR · IATA RTI · GPS WATR |
| Dhoho International Airport | `OURAIRPORTS:507227` | ID | ICAO WARD · IATA DHX · GPS WARD |
| Domine Eduard Osok Airport | `OURAIRPORTS:32634` | ID | ICAO WASS · IATA SOQ · GPS WASS |
| Karel Sadsuitubun Airport | `OURAIRPORTS:333039` | ID | ICAO WAPF · IATA LUV · GPS WAPF |
| Maleo Airport | `OURAIRPORTS:330319` | ID | ICAO WAFO · IATA MOH · GPS WAFO |
| Malikus Saleh Airport | `OURAIRPORTS:26861` | ID | ICAO WIMA · IATA LSW · GPS WIMA |
| Marinda Airport | `OURAIRPORTS:333091` | ID | ICAO WASN · IATA RJM · GPS WASN |
| Matahora Airport | `OURAIRPORTS:333072` | ID | ICAO WAWD · IATA WNI · GPS WAWD |
| Mathilda Batlayeri Airport | `OURAIRPORTS:311018` | ID | ICAO WAPS · IATA SXK · GPS WAPS |
| Mentawai Airport | `OURAIRPORTS:41397` | ID | ICAO WIEB · IATA RKI · GPS WIEB |
| Muara Bungo Airport | `OURAIRPORTS:310599` | ID | ICAO WIJB · IATA BUU · GPS WIJB |
| Namniwel Airport | `OURAIRPORTS:525059` | ID | ICAO WAPN · IATA NAM · GPS WAPN |
| Nop Goliat Dekai Airport | `OURAIRPORTS:315622` | ID | ICAO WAVD · IATA DEX · GPS WAVD |
| Notohadinegoro Airport | `OURAIRPORTS:46586` | ID | ICAO WARE · IATA JBB · GPS WARE |
| Nusawiru Airport | `OURAIRPORTS:3272` | ID | ICAO WICN · IATA CJN · GPS WICN |
| Old Nabire Airport | `OURAIRPORTS:26747` | ID | ICAO — · IATA — · GPS — |
| Sultan Bantilan Airport | `OURAIRPORTS:41440` | ID | ICAO WAFL · IATA TLI · GPS WAFL |
| Tabing Airport | `OURAIRPORTS:26838` | ID | ICAO — · IATA — · GPS — |
| Tanjung Api Airport | `OURAIRPORTS:506525` | ID | ICAO WAFU · IATA OJU · GPS WAFU |
| Toraja Airport | `OURAIRPORTS:352892` | ID | ICAO WAFB · IATA TRT · GPS WAFB |
| Amravati  Airport | `OURAIRPORTS:299082` | IN | ICAO VAAM · IATA AVR · GPS VAAM |
| Gondia Airport | `OURAIRPORTS:3299` | IN | ICAO VAGD · IATA GDB · GPS VAGD |
| Jalgaon Airport | `OURAIRPORTS:3303` | IN | ICAO VAJL · IATA JLG · GPS VAJL |
| Kazi Nazrul Islam Airport | `OURAIRPORTS:317982` | IN | ICAO VEDG · IATA RDP · GPS VEDG |
| Navi Mumbai International Airport | `OURAIRPORTS:342093` | IN | ICAO VANM · IATA NMI · GPS VANM |
| Shirdi International Airport | `OURAIRPORTS:327452` | IN | ICAO VASD · IATA SAG · GPS VASD |
| Sindhudurg Airport | `OURAIRPORTS:331218` | IN | ICAO VOSR · IATA SDW · GPS VOSR |
| Batken Airport | `OURAIRPORTS:3549` | KG | ICAO UCFB · IATA — · GPS UCFB |
| Jalal-Abad Airport | `OURAIRPORTS:41534` | KG | ICAO UCFD · IATA — · GPS UCFD |
| Naryn Airport | `OURAIRPORTS:41535` | KG | ICAO UCFN · IATA — · GPS UAFN |
| Dara Sakor International Airport | `OURAIRPORTS:339963` | KH | ICAO VDDS · IATA DSY · GPS VDDS |
| Wonsan Kalma Airport | `OURAIRPORTS:35213` | KP | ICAO ZKWS · IATA WOS · GPS ZKWS |
| Bokeo International Airport | `OURAIRPORTS:430434` | LA | ICAO VLBK · IATA BOR · GPS VLBK |
| Luxembourg-Findel International Airport | `OURAIRPORTS:2563` | LU | ICAO ELLX · IATA LUX · GPS ELLX |
| Ulaangom Airport | `OURAIRPORTS:302316` | MN | ICAO ZMUG · IATA ULO · GPS ZMUG |
| Nouakchott–Oumtounsy International Airport | `OURAIRPORTS:323315` | MR | ICAO GQNO · IATA NKC · GPS GQNO |
| Camaguey-Campo Cuatro Milpas Airport | `OURAIRPORTS:4897` | MX | ICAO — · IATA — · GPS — |
| Cedros Airport | `OURAIRPORTS:319370` | MX | ICAO — · IATA — · GPS — |
| Isla Cedros Airport | `OURAIRPORTS:4864` | MX | ICAO MMCD · IATA — · GPS MMCD |
| Mar de Cortés International Airport | `OURAIRPORTS:45229` | MX | ICAO MMPE · IATA PPE · GPS MMPE |
| Xai-Xai Chongoene Airport | `OURAIRPORTS:32579` | MZ | ICAO FQXA · IATA VJB · GPS FQXA |
| Twyfelfontein Airport | `OURAIRPORTS:595415` | NA | ICAO FYTF · IATA — · GPS FYTF |
| Bayelsa International Airport | `OURAIRPORTS:340295` | NG | ICAO DNBY · IATA — · GPS DNBY |
| Port Harcourt City Airport / Port Harcourt Air Force Base | `OURAIRPORTS:300565` | NG | ICAO DNPM · IATA PHG · GPS DNPM |
| Sir Abubakar Tafawa Balewa Bauchi State International Airport | `OURAIRPORTS:323056` | NG | ICAO DNBC · IATA BCU · GPS DNBC |
| Sir Ahmadu Bello International Airport | `OURAIRPORTS:313797` | NG | ICAO DNBK · IATA — · GPS DNBK |
| Umaru Musa Yar'adua Airport | `OURAIRPORTS:4971` | NG | ICAO DNKT · IATA DKA · GPS DNKT |
| Warri Airport | `OURAIRPORTS:32192` | NG | ICAO DNSU · IATA QRW · GPS DNSU |
| Pokhara International Airport | `OURAIRPORTS:342097` | NP | ICAO VNPR · IATA PHH · GPS VNPR |
| San Vicente Airport | `OURAIRPORTS:333098` | PH | ICAO RPSV · IATA SWL · GPS RPSV |
| New Gwadar International Airport | `OURAIRPORTS:342092` | PK | ICAO OPGW · IATA GWD · GPS OPGW |
| Antonio Rivera Rodriguez Airport | `OURAIRPORTS:6385` | PR | ICAO TJVQ · IATA VQS · GPS TJVQ |
| Eugenio Maria De Hostos Airport | `OURAIRPORTS:6382` | PR | ICAO TJMZ · IATA MAZ · GPS TJMZ |
| Fernando Luis Ribas Dominicci Airport | `OURAIRPORTS:6381` | PR | ICAO TJIG · IATA SIG · GPS TJIG |
| José Aponte de la Torre Airport | `OURAIRPORTS:42321` | PR | ICAO TJRV · IATA NRR · GPS TJRV |
| Luis Munoz Marin International Airport | `OURAIRPORTS:6384` | PR | ICAO TJSJ · IATA SJU · GPS TJSJ |
| Mercedita International Airport | `OURAIRPORTS:6383` | PR | ICAO TJPS · IATA PSE · GPS TJPS |
| Rafael Hernández International Airport | `OURAIRPORTS:6379` | PR | ICAO TJBQ · IATA BQN · GPS TJBQ |
| Teniente Ramon A. Ayub Gonzalez International Airport | `OURAIRPORTS:29851` | PY | ICAO SGEN · IATA ENO · GPS SGEN |
| Aleksandrovo Airport | `FICTIONAL:fictional:RS:LYAL` | RS | ICAO — · IATA — · GPS LYAL |
| Beloyarskiy Airport | `OURAIRPORTS:43692` | RU | ICAO USHQ · IATA EYK · GPS USHQ |
| Iturup Airport | `OURAIRPORTS:319423` | RU | ICAO UHSI · IATA ITU · GPS UHSI |
| Motygino Airport | `OURAIRPORTS:323478` | RU | ICAO — · IATA MJY · GPS UNIM |
| Nogliki Airport | `OURAIRPORTS:41838` | RU | ICAO — · IATA NGK · GPS UHSN |
| Srednekolymsk Airport | `OURAIRPORTS:316761` | RU | ICAO — · IATA SEK · GPS UESK |
| Tobolsk Remezov Airport | `OURAIRPORTS:342469` | RU | ICAO USTJ · IATA RMZ · GPS USTJ |
| Al-Ula International Airport | `OURAIRPORTS:300611` | SA | ICAO OEAO · IATA ULH · GPS OEAO |
| King Khaled Military City Airport | `OURAIRPORTS:5098` | SA | ICAO OEKK · IATA KMC · GPS OEKK |
| Türkmenabat International Airport | `OURAIRPORTS:26384` | TM | ICAO UTAV · IATA CRZ · GPS UTAV |
| Songwe Airport | `OURAIRPORTS:318875` | TZ | ICAO HTGW · IATA MBI · GPS HTGW |
| Lajitas International Airport | `OURAIRPORTS:14843` | US | ICAO — · IATA — · GPS KT89 |
| President Donald J. Trump International Airport | `OURAIRPORTS:3766` | US | ICAO KDJT · IATA DJT · GPS KDJT |
| Cyril E. King Airport | `OURAIRPORTS:6369` | VI | ICAO TIST · IATA STT · GPS TIST |
| Henry E. Rohlsen Airport | `OURAIRPORTS:6370` | VI | ICAO TISX · IATA STX · GPS TISX |

## Elevation not reported in pinned source — 22

| Airport | Key | Source country | Source codes |
|---|---|---|---|
| Mount Gambier Airport | `OURAIRPORTS:507498` | AU | ICAO YMTG · IATA MGB · GPS YMTG |
| Streatham Reef Hueston Airfield | `OURAIRPORTS:355458` | CA | ICAO — · IATA — · GPS CRHA |
| Anqing Tianzhushan Airport / Anqing North Air Base | `OURAIRPORTS:30650` | CN | ICAO ZSAQ · IATA AQG · GPS ZSAQ |
| Aral Tarim Airport | `OURAIRPORTS:354654` | CN | ICAO ZWAL · IATA ACF · GPS ZWAL |
| Bengbu Tenghu Airport | `OURAIRPORTS:598595` | CN | ICAO ZSBA · IATA BFY · GPS ZSBA |
| Cangyuan Washan Airport | `OURAIRPORTS:327447` | CN | ICAO ZPCW · IATA CWJ · GPS ZPCW |
| Changzhi Wangcun Airport | `OURAIRPORTS:30830` | CN | ICAO ZBCZ · IATA CIH · GPS ZBCZ |
| Dunhuang Mogao International Airport | `OURAIRPORTS:30929` | CN | ICAO ZLDH · IATA DNH · GPS ZLDH |
| Huangshan Tunxi International Airport | `OURAIRPORTS:32489` | CN | ICAO ZSTX · IATA TXN · GPS ZSTX |
| Jiansanjiang Shidi Airport | `OURAIRPORTS:327450` | CN | ICAO ZYJS · IATA JSJ · GPS ZYJS |
| Jieyang Chaoshan International Airport | `OURAIRPORTS:32400` | CN | ICAO ZGOW · IATA SWA · GPS ZGOW |
| Jiujiang Lushan Airport | `OURAIRPORTS:35309` | CN | ICAO ZSJJ · IATA JIU · GPS ZSJJ |
| Libo Airport | `OURAIRPORTS:327351` | CN | ICAO ZULB · IATA LLB · GPS ZULB |
| Shuozhou Zirun Airport | `OURAIRPORTS:526860` | CN | ICAO ZBSG · IATA SZH · GPS ZBSG |
| Tongren Fenghuang Airport | `OURAIRPORTS:302314` | CN | ICAO ZUTR · IATA TEN · GPS ZUTR |
| Ulanqab Jining Airport | `OURAIRPORTS:327445` | CN | ICAO ZBUC · IATA UCB · GPS ZBUC |
| Weifang Nanyuan Airport | `OURAIRPORTS:32646` | CN | ICAO ZSWF · IATA WEF · GPS ZSWF |
| Xiangxi Biancheng Airport | `OURAIRPORTS:514411` | CN | ICAO ZGXX · IATA DXJ · GPS ZGXX |
| Xilinhot Airport | `OURAIRPORTS:32700` | CN | ICAO ZBXH · IATA XIL · GPS ZBXH |
| Kishangarh Airport Ajmer | `OURAIRPORTS:327453` | IN | ICAO VIKG · IATA KQH · GPS VIKG |
| Aleksandrovo Airport | `FICTIONAL:fictional:RS:LYAL` | RS | ICAO — · IATA — · GPS LYAL |
| Oecusse Route of the Sandalwood International Airport | `OURAIRPORTS:35138` | TL | ICAO WPOC · IATA OEC · GPS WPOC |

## Other code handling

Local codes are not universally assigned. The 2,319 local-code nonreports are individually represented in the complete 3,141-row CSV and database audit but are not duplicated as a large list here. The previously imported `airlinerra.airport_codes` register retains all original evidence and statuses. No missing code has been synthesized.

## Source/provenance and next research actions

- Source ID: OurAirports pinned snapshot `11e4de2834aff6ab54c1f8fc89b8679ea3d08418`, public domain, already present in Airlinerra's identity repository; 3,119 elevations correlated by stable ID + country + physical coordinates.
- Candidate zones: MIT-licensed `mborsetti/airportsdata` dataset blob `8c339fc673992d7c8d8b95a24d5c113fe096695d`; accepted only after ICAO/IATA, country and <=10 km coordinate matching. 3,020 candidates; not official flight-time-zone verification.
- 121 time-zone candidates and 22 elevations remain unavailable (including fictional LYAL). Independently verify time zones against trustworthy geo zone mapping and the relevant AIP/airport source before activating routes.
- Official airport naming, all codes, municipality, region and coordinates must still undergo authoritative/source reconciliation. `NULL` is used rather than a fabricated value.
- Source evidence is stored individually in `airlinerra_game.airport_field_evidence` (3,119 elevation + 3,020 timezone claims) and the research statuses in `airport_identity_geography_audit` (3,141 lines).

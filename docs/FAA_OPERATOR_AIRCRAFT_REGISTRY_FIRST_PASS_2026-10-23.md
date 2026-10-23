# Airlinerra — FAA operator/aircraft linkage, first verification pass (2026-10-23)

FAA official Part 135 operators and aircraft landing page verified: https://www.faa.gov/about/officeorg/headquartersoffices/avs/faa-certificated-aircraft-operators-legal-part-135-holders . FAA says operator/aircraft spreadsheet is weekly updated and lists specific charter-authorized aircraft. Its linked XLSX could not be downloaded in this run (web fetch unsupported for Excel; container outbound access failed). **Therefore no operator's Part 135 certificate or aircraft operations specifications have been conclusively verified in this batch.** Keep these as NOT_CHECKED.

### Willow Run (FAA YIP): primary FAA aircraft registry discoveries
- FAA [N881MJ registry](https://registry.faa.gov/AircraftInquiry/Search/NNumberResult?nNumberTxt=881MJ): Learjet 45, registered owner **Kalitta Charters LLC**, Ypsilanti MI, marked registered/valid.
- FAA [N775SJ registry](https://registry.faa.gov/AircraftInquiry/Search/NNumberResult?nNumberTxt=775SJ): Boeing 737-48E, registered owner **Kalitta Charters II LLC**, Willow Run Airport address, marked registered/valid.
- FAA [June 2026 Part 121 RVSM approval document](https://www.faa.gov/sites/faa.gov/files/2026-06/NAARMO_US_Commercial_RVSM_Approvals_Part_121_Section_3_0.pdf) separately identifies **Kalitta Charters II LLC / N775SJ**. RVSM approval is not an air-carrier certificate, airport-service clearance or airplane performance validation.

**Crucial:** Aircraft ownership/registration does not show that it is in the operator's Part 135/121 certificate fleet, is actually based at YIP, is currently airworthy or permitted at the airport. Do not conflate Kalitta Air, Kalitta Charters and Kalitta Charters II.

### Database changes
Private `airlinerra.airport_commercial_verification` record for YIP now contains these dated official FAA aircraft-registry source links as a research note and a specific `next_action`. `game_admission_status` remains `NOT_APPROVED`; all service-verification and aircraft-compatibility checks remain pending. The previously prepared other five priority airports (GYH, PTK, RDG, GON, CIC) are unchanged. Original 3,140 and airport-world activation unchanged.

### Next checks
1. Obtain the latest downloadable FAA Part 135 operator-and-aircraft XLSX and independently inspect each operator legal name, designator, aircraft N-number, certifying office, snapshot date; consult AVInfo/FSDO for discrepancies.
2. For Kalitta Charters/Charters II, establish applicable Part 135 vs Part 121 authority and identify approved aircraft; for YIP verify operating flights, runway strength and operator usage.
3. Verify operator names and active aircraft for Groton charter (Action Airlines), Reading charter, Oakland County and Donaldson Field, without inferring legal authority from FBO listings.
4. Record separately operator identity, aircraft registration, actual service, airport permission, aircraft physical compatibility and evidence age. No gameplay approval before all gates pass.

-- Nonroad Post Processing Script (updated 6/23/2021):
-- Emission factors in grams per horsepower-hour by SCC
--  
-- MOVES-Nonroad Output Guidance:
--       SCC must be selected and present in the results. This script
--       will run faster if model year, engine tech, and HP class
--       are not selected, and if there is only one sector, year,
--       month, and day in the output.
-- 
-- When prompted to save, specify one of the following file types: .xlsx, .xls, or .txt
-- The raw output of this script is also stored in the output database in a table called:
-- EmissionFactors_per_hphr_by_SCC
-- 
-- WARNING:
--       This script may take a long time to complete depending on
--       the size of the output database. A confirmation notice will
--       alert you when this action has completed.

flush tables;

-- Set up indexing for setting NULL values to 0
set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_state');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_state already exists.''', 'create index index_state on movesoutput ( stateID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_state');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_state already exists.''', 'create index index_state on movesactivityoutput ( stateID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_county');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_county already exists.''', 'create index index_county on movesoutput ( countyID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_county');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_county already exists.''', 'create index index_county on movesactivityoutput ( countyID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_modelyear');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_modelyear already exists.''', 'create index index_modelyear on movesoutput ( modelYearID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_modelyear');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_modelyear already exists.''', 'create index index_modelyear on movesactivityoutput ( modelYearID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_engtech');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_engtech already exists.''', 'create index index_engtech on movesoutput ( engTechID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_engtech');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_engtech already exists.''', 'create index index_engtech on movesactivityoutput ( engTechID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_hp');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_hp already exists.''', 'create index index_hp on movesoutput ( hpID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_hp');
set @sqlstmt := if( @exist > 0, 'select ''INFO: index_hp already exists.''', 'create index index_hp on movesactivityoutput ( hpID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

-- Convert NULLs to 0 to improve joins
UPDATE movesoutput SET stateID = 0 WHERE stateID IS NULL;
UPDATE movesoutput SET countyID = 0 WHERE countyID IS NULL;
UPDATE movesoutput SET modelYearID = 0 WHERE modelYearID IS NULL;
UPDATE movesoutput SET engTechID = 0 WHERE engTechID IS NULL;
UPDATE movesoutput SET hpID = 0 WHERE hpID IS NULL;
UPDATE movesactivityoutput SET stateID = 0 WHERE stateID IS NULL;
UPDATE movesactivityoutput SET countyID = 0 WHERE countyID IS NULL;
UPDATE movesactivityoutput SET modelYearID = 0 WHERE modelYearID IS NULL;
UPDATE movesactivityoutput SET engTechID = 0 WHERE engTechID IS NULL;
UPDATE movesactivityoutput SET hpID = 0 WHERE hpID IS NULL;

-- Set up indexing for everything else
set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index1');
set @sqlstmt := if( @exist > 0, 'select ''INFO: Index already exists.''', 'create index index1 on movesoutput ( MOVESRunID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index101');
set @sqlstmt := if( @exist > 0, 'select ''INFO: Index already exists.''', 'create index index101 on movesoutput ( MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc,pollutantID,processID )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index10');
set @sqlstmt := if( @exist > 0, 'select ''INFO: Index already exists.''', 'create index index10 on movesactivityoutput ( activitytypeid )');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

-- Get time units
set @timeUnits := (select timeUnits from movesrun limit 1);

-- Calculate total horsepower*hours*loadfactor before any aggregation occurs
-- Select all of the rows where the activity column represents source hours and
--   merge them with all of the rows where the activity column represents the average horsepower and
--   merge them with all of the rows where the activity column represents the load factor
drop table if exists sourceHours;
create table sourceHours
select 
	MOVESRunID,
	yearID,
	monthID,
	dayID,
	stateID,
	countyID,
	SCC,
	modelYearID,
	engTechID,
	hpID,
	activity as sourceHours
from movesactivityoutput  
where activitytypeid = 2;

drop table if exists horsepower;
create table horsepower
select 
	MOVESRunID,
	yearID,
	monthID,
	dayID,
	stateID,
	countyID,
	SCC,
	modelYearID,
	engTechID,
	hpID,
	activity as avgHorsepower 
from movesactivityoutput  
where activitytypeid = 9;

drop table if exists loadfactor;
create table loadfactor
select 
	MOVESRunID,
	yearID,
	monthID,
	dayID,
	stateID,
	countyID,
	SCC,
	modelYearID,
	engTechID,
	hpID,
	activity as loadFactor 
from movesactivityoutput  
where activitytypeid = 12;

create index index1 on sourceHours (MOVESRunID,yearID,monthID,dayID,stateID,countyID,SCC,modelYearID,engTechID,hpID);
create index index1 on horsepower (MOVESRunID,yearID,monthID,dayID,stateID,countyID,SCC,modelYearID,engTechID,hpID);
create index index1 on loadfactor (MOVESRunID,yearID,monthID,dayID,stateID,countyID,SCC,modelYearID,engTechID,hpID);

-- Note: JOIN followed by ALTER is used instead of a single statement with multiple joins
--   because if the tables are very large, the separate statements are much faster
drop table if exists hphr;
create table hphr
select
	b1.MOVESRunID,
	b1.yearID,
	b1.monthID,
	b1.dayID,
	b1.stateID,
	b1.countyID,
	b1.SCC,
	b1.modelYearID,
	b1.engTechID,
	b1.hpID,
	b1.sourceHours,
	b2.avgHorsepower
from sourceHours b1
join horsepower b2 USING (MOVESRunID,yearID,monthID,dayID,stateID,countyID,SCC,modelYearID,engTechID,hpID);

create index index1 on hphr (MOVESRunID,yearID,monthID,dayID,stateID,countyID,SCC,modelYearID,engTechID,hpID);

alter table hphr add loadFactor double, add hpHours double;
update hphr b1, loadFactor b3
set b1.loadFactor = b3.loadFactor,
	b1.hpHours = avgHorsepower * sourceHours * b3.loadFactor
 where (b1.MOVESRunID=b3.MOVESRunID) AND
		(b1.yearID=b3.yearID) AND 
		(b1.monthID=b3.monthID) AND 
		(b1.dayID=b3.dayID) AND 
		(b1.stateID=b3.stateID) AND 
		(b1.countyID=b3.countyID) AND 
		(b1.SCC=b3.SCC) AND 
		(b1.modelYearID=b3.modelYearID) AND 
		(b1.engTechID=b3.engTechID) AND 
		(b1.hpID=b3.hpID OR b1.hpID);

create index index2 on hphr (MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc);


-- Set up unit conversions table
drop table if exists units;
create table units (fromUnit char(5), factor double, description text);
insert into units values 
('ton', 907185, 'From U.S. tons to grams'),
('lb', 453.592, 'From lbm to grams'),
('kg', 1000, 'From kg to grams'),
('g', 1, 'From grams to grams');

-- Get inventories by SCC
drop table if exists temp1;
create table temp1
select 
	MOVESRunID,
	yearID,
	monthID,
	dayID,
	stateID,
	countyID,
	scc,
    pollutantID,
    processID,
    units.factor * sum(emissionQuant) as emissionQuant
from movesoutput m
left join movesrun using (movesrunid)
left join units on (movesrun.massUnits = units.fromUnit)
group by MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc,pollutantID,processID;
	     
create index index1 on temp1 (MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc);
create index index2 on temp1 (scc);


-- Get horsepower-hours by SCC
drop table if exists temp2;
create table temp2
select
	MOVESRunID,
	yearID,
	monthID,
	dayID,
	stateID,
	countyID,
	scc,
    sum(hpHours) as hpHours
from hphr
group by MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc;

create index index1 on temp2 (MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc);


-- Join temp1 and temp2 and calculate the emission rate for the resulting output table
drop table if exists EmissionFactors_per_hphr_by_SCC;
create table EmissionFactors_per_hphr_by_SCC
select
	b1.MOVESRunID,
	b1.yearID,
	b1.monthID,
	b1.dayID,
	b1.stateID,
	b1.countyID,
	b1.scc,
	s.description as sccDescription,
	s.fuelTypeID,
    b1.pollutantID,
    b1.processID,
	b1.emissionQuant,
    b2.hpHours,
    IF(b2.hpHours != 0, b1.emissionQuant / b2.hpHours, NULL) as emissionRate,
    'g/hp-hr' as emissionRateUnits
from temp1 b1
inner join temp2 b2 USING (MOVESRunID,yearID,monthID,dayID,stateID,countyID,scc)
left join ##defaultdb##.nrscc s on (b1.scc=s.scc);

-- Drop intermediate tables and the primary indexes
drop table if exists sourceHours;
drop table if exists horsepower;
drop table if exists loadfactor;
drop table if exists temp1;
drop table if exists temp2;
drop table if exists hphr;
drop table if exists units;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index1');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index1 does not exist.''', 'drop index index1 on movesoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index101');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index101 does not exist.''', 'drop index index101 on movesoutput');
PREPARE stmt FROM @sqlstmt;																						
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index10');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index10 does not exist.''', 'drop index index10 on movesactivityoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

-- Revert 0s to NULLs
UPDATE movesoutput SET stateID = NULL WHERE stateID = 0;
UPDATE movesoutput SET countyID = NULL WHERE countyID = 0;
UPDATE movesoutput SET modelYearID = NULL WHERE modelYearID = 0;
UPDATE movesoutput SET engTechID = NULL WHERE engTechID = 0;
UPDATE movesoutput SET hpID = NULL WHERE hpID = 0;
UPDATE movesactivityoutput SET stateID = NULL WHERE stateID = 0;
UPDATE movesactivityoutput SET countyID = NULL WHERE countyID = 0;
UPDATE movesactivityoutput SET modelYearID = NULL WHERE modelYearID = 0;
UPDATE movesactivityoutput SET engTechID = NULL WHERE engTechID = 0;
UPDATE movesactivityoutput SET hpID = NULL WHERE hpID = 0;

-- drop the rest of the indexes
set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_state');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_state does not exist.''', 'drop index index_state on movesoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_state');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_state does not exist.''', 'drop index index_state on movesactivityoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_county');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_county does not exist.''', 'drop index index_county on movesoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_county');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_county does not exist.''', 'drop index index_county on movesactivityoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_modelyear');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_modelyear does not exist.''', 'drop index index_modelyear on movesoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_modelyear');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_modelyear does not exist.''', 'drop index index_modelyear on movesactivityoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_engtech');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_engtech does not exist.''', 'drop index index_engtech on movesoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_engtech');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_engtech does not exist.''', 'drop index index_engtech on movesactivityoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesoutput' and index_name = 'index_hp');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_hp does not exist.''', 'drop index index_hp on movesoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

set @exist := (select count(*) from information_schema.statistics where table_schema = DATABASE() and table_name = 'movesactivityoutput' and index_name = 'index_hp');
set @sqlstmt := if( @exist = 0, 'select ''INFO: index_hp does not exist.''', 'drop index index_hp on movesactivityoutput');
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;

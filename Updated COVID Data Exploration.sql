/** COVID-19 Data Exploration using SQL Server

Data from Our World in Data COVID-19 Public dataset https://github.com/owid/covid-19-data/tree/master/public/data

**/

--Check basic information for the CasesDeaths table
Use PortfolioProject
exec sp_columns
	@table_name = 'CasesDeaths'

--Change data types for easier analysis
Alter table CasesDeaths Alter column total_deaths int;

Alter table CasesDeaths Alter column new_deaths int;

Alter table CasesDeaths Alter column reproduction_rate float;

--Check basic information for the Tests table
Use PortfolioProject
exec sp_columns
	@table_name = 'Tests';
--Change data types for easier analysis
Alter table Tests Alter Column new_tests numeric

Alter table Tests Alter Column total_tests numeric

Alter table Tests Alter Column positive_rate float

Alter table Tests Alter column tests_per_case float

Alter table Tests Alter column new_tests_per_thousand numeric

Use PortfolioProject

Alter table Hospitalizations Alter Column hosp_patients numeric

Alter table Hospitalizations Alter Column icu_patients numeric

--Peek into the tables
select top 100 * from PortfolioProject..CasesDeaths
order by 3,4

select top 100 * from PortfolioProject..Tests
where total_tests is not null
order by 3,4

select top 100 * from PortfolioProject..Hospitalizations
where hosp_patients is not null
and location like '%states%'
order by 3,4

select top 100 * from PortfolioProject..Vaccinations
where location like '%states%'

select top 100 * from PortfolioProject..Demographics
where location like '%states%'

--Explore United States based trends

--Return test data for the whole duration of the pandemic, including test positivity rate (7-day and daily)
select C.location, C.date, T.total_tests, T.new_tests, c.total_cases, C.new_cases, t.positive_rate seven_day_rolling_positive_rate,
isnull(ROUND(C.new_cases / t.new_tests, 2),0) daily_positive_rate,
case 
	when t.positive_rate > 0.05 then 'Above 5% Benchmark'
	when t.Positive_rate = 0.05 then 'At 5% Benchmark'
	when t.positive_rate < 0.05 then 'Below 5% Benchmark' else 'No Data' end 'test_positivity_benchmark', --How does seven-day rolling test positivity % compare to WHO Benchmark of 5%
t.tests_per_case,
t.new_tests_per_thousand
from PortfolioProject..CasesDeaths C
join PortfolioProject..Tests T
on C.location = T.location
	and C.date = T.date
where t.total_tests is not null
and c.location like '%states%'
order by C.location, C.date

--Drill down on test positivity and new test trends
--How can the test positivity rate and changes in # of new tests administered explain current COVID transmission?
select Temp.location, Temp.date, Temp.new_tests, Temp.new_cases, Temp.seven_day_rolling_positive_rate, Temp.test_positivity_benchmark, Temp.seven_day_rolling_tests,

cast(((Temp.seven_day_rolling_tests - Temp.prior_seven_day_rolling_tests) / nullif(Temp.prior_seven_day_rolling_tests,0)) as decimal(8,4)) 'percent_change_rolling_avg_over_prior',

case 
	when ((Temp.seven_day_rolling_tests - Temp.prior_seven_day_rolling_tests) / nullif(Temp.prior_seven_day_rolling_tests,0)) < 0 then 'Tests Decreasing'
	when ((Temp.seven_day_rolling_tests - Temp.prior_seven_day_rolling_tests) / nullif(Temp.prior_seven_day_rolling_tests,0)) between 0 and 0.02 then 'Tests Flat'
	else 'Tests Increasing'
	end as 'testing_trend'

from
(
	select C.location, C.date, T.new_tests, C.new_cases, t.positive_rate seven_day_rolling_positive_rate,
	isnull(ROUND(C.new_cases / t.new_tests, 2),0) daily_positive_rate,
	case 
		when t.positive_rate > 0.05 then 'Above 5% Benchmark'
		when t.Positive_rate = 0.05 then 'At 5% Benchmark'
		when t.positive_rate < 0.05 then 'Below 5% Benchmark' else 'No Data' end 'test_positivity_benchmark',
	t.tests_per_case,
	t.new_tests_per_thousand,
	cast(avg(t.new_tests) OVER (partition by C.location order by C.location, C.date rows between 6 preceding and current row) as decimal(12,2)) as seven_day_rolling_tests,
	cast(avg(t.new_tests) OVER (partition by C.location order by C.location, C.date rows between 13 preceding and 7 preceding) as decimal(12,2)) as prior_seven_day_rolling_tests
	from PortfolioProject..CasesDeaths C
	join PortfolioProject..Tests T
	on C.location = T.location
		and C.date = T.date
	where t.total_tests is not null
	and c.location like '%states%'
) Temp
order by Temp.Date

--When test positivity was above 5%, what days was the testing trend decreasing (implying broader transmission)
--Add an additional subquery layer to sort the return data
select *,
	concat(DATENAME(Month,Temp2.Date),'-',DATEPART(Year,Temp2.Date)) 'date_bucket'

from
(
	select Temp.location, Temp.date, Temp.new_tests, Temp.new_cases, Temp.seven_day_rolling_positive_rate, Temp.test_positivity_benchmark, Temp.seven_day_rolling_tests,

	cast(((Temp.seven_day_rolling_tests - Temp.prior_seven_day_rolling_tests) / nullif(Temp.prior_seven_day_rolling_tests,0)) as decimal(8,4)) 'percent_change_rolling_avg_over_prior',

	case 
		when ((Temp.seven_day_rolling_tests - Temp.prior_seven_day_rolling_tests) / nullif(Temp.prior_seven_day_rolling_tests,0)) < 0 then 'Tests Decreasing'
		when ((Temp.seven_day_rolling_tests - Temp.prior_seven_day_rolling_tests) / nullif(Temp.prior_seven_day_rolling_tests,0)) between 0 and 0.02 then 'Tests Flat'
		else 'Tests Increasing'
		end as 'testing_trend'

	from
	(
		select C.location, C.date, T.new_tests, C.new_cases, t.positive_rate seven_day_rolling_positive_rate,
		isnull(ROUND(C.new_cases / t.new_tests, 2),0) daily_positive_rate,
		case 
			when t.positive_rate > 0.05 then 'Above 5% Benchmark'
			when t.Positive_rate = 0.05 then 'At 5% Benchmark'
			when t.positive_rate < 0.05 then 'Below 5% Benchmark' else 'No Data' end 'test_positivity_benchmark',
		t.tests_per_case,
		t.new_tests_per_thousand,
		cast(avg(t.new_tests) OVER (partition by C.location order by C.location, C.date rows between 6 preceding and current row) as decimal(12,2)) as seven_day_rolling_tests,
		cast(avg(t.new_tests) OVER (partition by C.location order by C.location, C.date rows between 13 preceding and 7 preceding) as decimal(12,2)) as prior_seven_day_rolling_tests
		from PortfolioProject..CasesDeaths C
		join PortfolioProject..Tests T
		on C.location = T.location
			and C.date = T.date
		where t.total_tests is not null
		and c.location like '%states%'
	) Temp
) Temp2
where test_positivity_benchmark = 'Above 5% Benchmark' and testing_trend = 'Tests Decreasing'
order by seven_day_rolling_positive_rate desc, percent_change_rolling_avg_over_prior desc


--Determining the seven day rolling averages for cases and deaths in the United States
select location, date, total_cases, new_cases, 
avg(new_cases) OVER (partition by location order by location, date rows between 6 preceding and current row) as seven_day_rolling_cases,
total_deaths, new_deaths, 
avg(new_deaths) OVER (partition by location order by location, date rows between 6 preceding and current row) as seven_day_rolling_deaths,
(total_deaths / total_cases) fatality_ratio,
reproduction_rate --measures the estimated growth or decline of the virus' spread
--R > 1 = outbreak growing, R < 1 = outbreak declining 
from PortfolioProject..CasesDeaths
where location like '%states%'

--What days thus far in the pandemic have the most lives been lost? What were the reported case figures during those days?
select location, date, total_cases, new_cases, 
avg(new_cases) OVER (partition by location order by location, date rows between 6 preceding and current row) as seven_day_rolling_cases,
total_deaths, new_deaths, 
avg(new_deaths) OVER (partition by location order by location, date rows between 6 preceding and current row) as seven_day_rolling_deaths,
(total_deaths / total_cases) fatality_ratio,
reproduction_rate --measures the estimated growth or decline of the virus' spread
--R > 1 = outbreak growing, R < 1 = outbreak declining 
from PortfolioProject..CasesDeaths
where location like '%states%'
order by new_deaths desc, new_cases desc


--Explore Vaccination data
select V.location, V.date, D.population, V.new_vaccinations, V.people_vaccinated, V.people_fully_vaccinated, V.total_boosters
from PortfolioProject..Vaccinations V
join PortfolioProject..Demographics D
on V.location = D.location
	and V.date = D.date
where V.location like '%states%'
and V.people_vaccinated is not null
order by V.date

--Show vaccination progress as a % of the population

--Use CTE
with Vax_Progress (location, date, population, new_vaccinations, people_vaccinated, people_fully_vaccinated, total_boosters, cumulative_count_vaccinations)
as
(
select V.location, V.date, D.population, cast(V.new_vaccinations as numeric), cast(V.people_vaccinated as numeric), cast(V.people_fully_vaccinated as numeric), cast(V.total_boosters as numeric),
sum(cast(V.new_vaccinations as numeric)) over (partition by V.location order by V.location, V.date) cumulative_count_vaccinations
from PortfolioProject..Vaccinations V
join PortfolioProject..Demographics D
on V.location = D.location
	and V.date = D.date
where V.location like '%states%'
and V.people_vaccinated is not null
and V.continent is not null
)

select *,
cast((people_vaccinated/population) as decimal(8,2)) percent_pop_one_dose,
cast((people_fully_vaccinated/population) as decimal(8,2)) percent_pop_fully_vaxxed,
cast((total_boosters/people_fully_vaccinated) as decimal(8,2)) percent_boostered_of_fully_vaxxed
from Vax_Progress


--Explore Global Data
--What countries have the highest total infection count
--Return top 20
select top 20
	C.location,
	D.population,
	max(c.total_cases) highest_infection_count,
	max(c.total_cases/d.population) highest_percent_infected
from PortfolioProject..CasesDeaths C
join PortfolioProject..Demographics D
on C.location = D.location
and c.date = D.date
where C.continent is not null

group by
	C.location,
	D.population
order by 3 desc

--What do the total death and vaccination rates look like for these countries?
--Show using Temp Table
Drop Table if exists #TempPercentInfected
Create table #TempPercentInfected
(location nvarchar(255),
population numeric,
highest_infection_count numeric,
highest_percent_infected decimal(8,2))

Insert into #TempPercentInfected

select top 20
	C.location,
	D.population,
	max(c.total_cases) highest_infection_count,
	max(c.total_cases/d.population) highest_percent_infected
from PortfolioProject..CasesDeaths C
join PortfolioProject..Demographics D
on C.location = D.location
and c.date = D.date
where C.continent is not null

group by
	C.location,
	D.population
order by 3 desc

select
	C.location,
	max(C.total_deaths) total_deaths, 
	max(C.total_deaths_per_million) total_deaths_per_million,
	max(V.people_fully_vaccinated) people_fully_vaccinated,
	max(V.people_fully_vaccinated_per_hundred) people_fully_vaccinated_per_hundred
from PortfolioProject..CasesDeaths C
join PortfolioProject..Vaccinations V
on C.location = V.location
and C.date = V.date
where C.location in
	(select location from #TempPercentInfected)
group by C.location
order by max(C.total_cases) desc
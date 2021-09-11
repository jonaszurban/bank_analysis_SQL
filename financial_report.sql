USE financial;

/* Wyciągamy informacje na temat sumy pożyczek, całkowitej ilości pożyczek oraz średniej kwoty pożyczki grupując
   dane na lata, kwartały oraz miesiące. */
SELECT EXTRACT(YEAR FROM date) AS year, EXTRACT(QUARTER FROM date) AS quarter, EXTRACT(MONTH FROM date) AS month,
       SUM(amount) AS total_loan_amount, AVG(amount) AS avg_loan_amount, COUNT(*) as quantity_of_loans FROM loan
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(QUARTER FROM date), EXTRACT(MONTH FROM date) WITH ROLLUP
ORDER BY year DESC, quarter, month;

/* Pożyczki mają przypisane 4 statusy - A,B,C,D. Musimy wywnioskować, które statusy oznaczają pożyczki spłacone,
   a które pożyczki niespłacone. Z dokumentacji danych można wynieść informacje, że całkowita ilość pożyczek to 682,
   z czego 606 pożyczek zostało spłaconych, a 76 pożyczek niespłaconych. */
SELECT count(*) as quantity FROM loan; -- ilość pożyczek

SELECT status, COUNT(*) as quantity FROM loan
GROUP BY status;
/* Z wyniku zapytania można wywnioskować, że status pożyczek A i C oznacza pożyczki spłacone, natomiast B i D to
   pożyczki niespłacone. */

/* Poniższa kwerenda rankuje konta według: liczby udzielonych pożyczek oraz kwoty udzielonych pożyczek. Wyznaczona
   została także średnia kwota pożyczek. */
WITH cte AS (SELECT a.account_id, COUNT(l.amount) AS loans_count, SUM(l.amount) AS loans_amount, avg(l.amount) AS avg_loan_amount FROM account a
JOIN loan l on l.account_id=a.account_id
WHERE l.status IN ('A','C')
GROUP BY a.account_id)
SELECT *, ROW_NUMBER() OVER (ORDER BY loans_count DESC) AS loans_count_rank,
       ROW_NUMBER() OVER (ORDER BY loans_amount DESC) AS loans_amount_rank
FROM cte;

/* W kolejnym zapytaniu chcemy sprawdzić, której płci klienci posiadają większość ilość pożyczek. W analizie
   bierzemy pod uwagę tylko pożczyki spłacone oraz klientów ze statusem właściciela konta (d.type='OWNER'). */

SELECT c.gender, COUNT(l.loan_id) AS loans_count FROM client c
JOIN disp d ON c.client_id = d.client_id
JOIN account a ON a.account_id = d.account_id
JOIN loan l on a.account_id = l.account_id
WHERE l.status IN ('A','C') AND d.type='OWNER'
GROUP BY c.gender;

/* Zapisujemy wyniki w postaci tabeli tymczasowej. */
CREATE TEMPORARY TABLE IF NOT EXISTS loans_count_gender AS (SELECT c.gender, COUNT(l.loan_id) AS loans_count FROM client c
JOIN disp d ON c.client_id = d.client_id
JOIN account a ON a.account_id = d.account_id
JOIN loan l on a.account_id = l.account_id
WHERE l.status IN ('A','C') AND d.type='OWNER'
GROUP BY c.gender);

SELECT * FROM loans_count_gender;

/* ANALIZA KLIENTA cz 1
   W kolejnych kwerendach będziemy szukać odpowiedzi na wybrane pytania.
 */
-- 1. Która płeć posiada więcej spłaconych kredytów?
SELECT * FROM loans_count_gender ORDER BY loans_count DESC LIMIT 1;

-- 2. Jaki jest średni wiek kredytobiorcy w zależności od płci?
SELECT c.gender, COUNT(l.loan_id) AS loans_count,ROUND(AVG(2021-YEAR(c.birth_date)),0) AS avg_age FROM client c
JOIN disp d ON c.client_id = d.client_id
JOIN account a ON a.account_id = d.account_id
JOIN loan l on a.account_id = l.account_id
WHERE l.status IN ('A','C') AND d.type='OWNER'
GROUP BY c.gender;

/* ANALIZA KLIENTA cz 2
   Do drugiej części analizy wykorzystamy inny schemat rozwiązania - najpierw stworzymy tabele tymczasową z
   potrzebnymi danymi, dzięki czemu kolejne zapytania będą krótsze. Do tabeli włączymy dane takie jak region
   pochodzenia klienta, ilość klientów w regionie, ilość pożyczek oraz całkowitą sumę pobranych pożyczek
   pogrupowane na regiony pochodzenia klientów. */

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_district_analytics AS(
    SELECT dt.A3 AS district, COUNT(c.client_id) AS customer_count, COUNT(l.loan_id) AS loans_count,
    SUM(l.amount) AS loans_amount FROM loan l
    JOIN account a on l.account_id = a.account_id
    JOIN disp dp on a.account_id = dp.account_id
    JOIN district dt ON a.district_id = dt.district_id
    JOIN client c on dp.client_id = c.client_id
    WHERE dp.type='OWNER' AND l.status IN ('A','C')
    GROUP BY district);

SELECT * FROM tmp_district_analytics;

-- 1. W którym regionie jest najwięcej klientów?
SELECT district, customer_count FROM tmp_district_analytics ORDER BY customer_count DESC LIMIT 1;

-- 2. W którym regionie zostało spłaconych najwięcej pożyczek?
SELECT district, loans_count FROM tmp_district_analytics ORDER BY loans_count DESC LIMIT 1;

-- 3. W którym rejonie zostało spłaconych najwięcej pożyczek kwotowo?
SELECT district, loans_amount FROM tmp_district_analytics ORDER BY loans_amount DESC LIMIT 1;

/* W tej części analizy sprawdzamy udział całkowitej sumy pożyczek per region w całkowitej sprzedaży ogólnej,
   udział iłości pożyczek per region w całkowitej ilości pożyczek. */
WITH cte AS(SELECT dt.A3 AS district, COUNT(l.amount) AS district_loans_count, SUM(l.amount) AS district_loans_amount
FROM district dt
JOIN account a ON dt.district_id = a.district_id
JOIN loan l ON l.account_id=a.account_id
WHERE l.status IN ('A','C')
GROUP BY dt.A3)
SELECT *, district_loans_amount/SUM(district_loans_amount) OVER () AS share FROM cte;

/* Sprawdzamy czy są klienci, którzy posiadają więcej niż 5 pożyczek oraz do spłaty więcej niż 1000 CZK (koron
   czeskich, zakładamy że w takiej walucie są podane informacje na temat płatności oraz pożyczek.) Spłatę wyliczamy
   przez odjęcie od sumy pożyczki (amount) płatności (payments). */
SELECT c.client_id, SUM(l.amount-l.payments) AS client_balance, count(l.loan_id) AS client_loans FROM loan l
JOIN account a ON a.account_id=l.account_id
JOIN disp dp ON dp.account_id=a.account_id
JOIN client c ON c.client_id=dp.client_id
WHERE dp.type='OWNER' AND l.status IN ('A','C')
GROUP BY c.client_id
HAVING client_balance>1000
AND client_loans>5;

/* Ostatnie zadanie to stworzenie procedury mającej za zadanie uzupełnić stworzyć tabelę zawierającą
   informację na temat kart kredytowych, które mają date wygaśnięcia w ciągu 14 dni od wybranej daty.
   Zakładamy, że karta kredytowa jest ważna 3 lata. Wyciągamy także id klienta oraz region, żeby
   wiedzieć gdzie i do kogo mamy wysłać nową kartę kredytową. */
DROP TABLE IF EXISTS cards_at_expiration;
CREATE TABLE cards_at_expiration(client_id INT NOT NULL, card_id INT NOT NULL, expiration_date DATE NULL,
district VARCHAR(20), report_generation_date DATE NULL);
SELECT * FROM cards_at_expiration;

DROP PROCEDURE IF EXISTS cards_expiration_report;
DELIMITER $$
CREATE PROCEDURE cards_expiration_report (IN report_date DATE)
BEGIN
    TRUNCATE TABLE cards_at_expiration;
    INSERT INTO cards_at_expiration
    WITH cte AS(
        SELECT cl.client_id, cd.card_id, DATE_ADD(cd.issued, INTERVAL 3 YEAR) AS card_expiration_date, dt.A3
        FROM client cl
    JOIN disp dp ON dp.client_id=cl.client_id
    JOIN card cd ON cd.disp_id=dp.disp_id
    JOIN district dt ON dt.district_id=cl.district_id
    WHERE dp.type='OWNER')
    SELECT *, report_date FROM cte
    WHERE report_date BETWEEN DATE_ADD(card_expiration_date,INTERVAL -14 DAY) AND card_expiration_date;
end $$

DELIMITER ;

-- test procedury
CALL cards_expiration_report('2001-01-01');
SELECT * FROM cards_at_expiration;
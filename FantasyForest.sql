/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Казаков Александр Дмитриевич
 * Дата: 30.08.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- кол-во всего пользователей, кол-во плативгих и доля от общего кол-ва
SELECT
	total_users,
	payer_count,
	payer_count / total_users::float AS share_payer_us
FROM(
	SELECT
		count(*) AS total_users,
		count(CASE WHEN payer = 1 THEN 1 END) AS payer_count -- c case подглядел у нейронки, изначально хотел при помощи подзапроса делать
	FROM FANTASY.USERS
);

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- нахождение зависимости по платящим ползователям относительно рассы
SELECT
	race,
	count_race,
	count_race_payer,
	ROUND(count_race_payer::numeric / count_race,2) AS share_payer_race
FROM (
	SELECT
		race,
		count(CASE WHEN payer = 1 THEN 1 END) AS count_race_payer, -- по прошлому опыту, уже применял самостоятельно
		count(*) AS count_race
	FROM FANTASY.USERS
	JOIN FANTASY.RACE USING(race_id)
	GROUP BY race
)
ORDER BY share_payer_race DESC;
-- по результатам можно заметить, что самой большой рассой являются 'Human', но наибольшую долю купивших относильно всех пользователей
-- рассы, занимают Demon, но отличия с остальными рассами не значительное

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
	COUNT(amount) AS count_amount,
	SUM(amount) AS sum_amount,
	MAX(amount) AS max_amount,
	MIN(amount) AS min_amount,
	ROUND(AVG(amount)::numeric,2) AS avg_amount,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)::NUMERIC,2) AS median_amount,
	ROUND(STDDEV(amount)::numeric,2) AS stand_amount
FROM FANTASY.EVENTS;

-- 2.2: Аномальные нулевые покупки:
SELECT
	COUNT(*) AS total_count,
	count(CASE WHEN amount = 0 THEN 1 END) AS zero_count,
	count(CASE WHEN amount = 0 THEN 1 END) / COUNT(*)::numeric AS shared_zero
FROM FANTASY.EVENTS;

-- 2.3: Популярные эпические предметы:
SELECT
	game_items,
	count_items,
	ROUND(count_items / sum(count_items) OVER (),2) AS shared_items,
	ROUND(share_users,3) AS share_users
FROM(
	SELECT
		item_code,
		game_items,
		COUNT(*) AS count_items, 
		count(DISTINCT id)::numeric / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0) AS share_users
	FROM FANTASY.EVENTS
	JOIN FANTASY.ITEMS USING(item_code)
	WHERE amount > 0
	GROUP BY item_code,game_items
)
ORDER BY share_users DESC;


-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH info_payer_users AS (
	SELECT
		race,
		COUNT(distinct u.id) AS total_users,
		COUNT(DISTINCT events.id) AS payer_users,
		ROUND(COUNT(DISTINCT events.id)::numeric / COUNT(DISTINCT u.id), 4) AS share_payer_in_users,
		ROUND(COUNT(DISTINCT CASE WHEN u.payer = 1 THEN events.id END)::numeric / COUNT(DISTINCT events.id), 4) AS share_payer_in_byer
	FROM FANTASY.USERS u
	FULL JOIN FANTASY.EVENTS ON u.id = events.id AND amount <> 0 
	JOIN FANTASY.RACE USING(race_id)
	GROUP BY race 
	),
count_table AS(
	SELECT
		id,
		race,
		count(*) AS total_count,
		SUM(AMOUNT ) AS sum_amount
	FROM FANTASY.EVENTS
	JOIN FANTASY.USERS USING(id)
	JOIN FANTASY.RACE using(race_id)
	WHERE amount <> 0
	GROUP BY id, race
),
avg_table as(
	SELECT 
		race,
		ROUND(avg(total_count)::numeric) AS avg_orders_per_payer,
		ROUND(avg(sum_amount)::NUMERIC / avg(total_count)) AS avg_receipt_per_payer,
		ROUND(avg(sum_amount)::numeric) AS avg_total_per_payer
	FROM count_table
	GROUP BY race
)
SELECT
	*
FROM info_payer_users
JOIN avg_table USING(race); 

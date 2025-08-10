-- Задача 1.
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- делаем сте для категорий длительности объявления и категорий СПб-ЛенОбл
days_city_category AS (
	SELECT id, last_price, days_exposition,
		CASE WHEN a.days_exposition <= 30 THEN '1 До месяца'
			WHEN a.days_exposition BETWEEN 31 AND 90 THEN '2 До 3х месяцев'
			WHEN a.days_exposition BETWEEN 91 AND 180 THEN '3 До полугода'
			ELSE '4 Больше полугода'
			END AS act_segments,
		CASE WHEN c.city = 'Санкт-Петербург' THEN city
			ELSE 'ЛенОбл'
		END AS regions
	FROM real_estate.advertisement a
	FULL JOIN (SELECT id, city_id FROM real_estate.flats) f USING (id)
	FULL JOIN real_estate.city c USING (city_id)
	WHERE days_exposition IS NOT NULL	
	)
-- Выведем статистику по регионам и сегментам активности:
SELECT regions, act_segments, 
	COUNT(*) AS exposition_cnt, -- кол-во публикаций
	round(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC,2) AS share_total, --доля публикаций от общего числа публикаций
	round(COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY regions)::numeric,2) exp_region_share, -- доля публикаций от общего числа по региону
	round(AVG(d.days_exposition)) AS avg_active_time, -- среднее время активности публикации
	round((SUM(last_price)/SUM(total_area))::numeric,2) AS avg_price_m2, -- срденяя цена м2
	round(AVG(total_area)::numeric,2) AS avg_total_area, -- средняя площадь жилья
	round(AVG(last_price)) AS avg_total_price,  -- средняя стоимость жилья
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,  -- медиана кол-ва комнат в жилье
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median, -- медиана кол-ва балконов в жилье
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS floor_median,  -- медиана этажа квартиры
	round(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ceiling_height)::numeric,2) AS ceiling_h_median -- медиана высоты потолка
FROM real_estate.flats f
INNER JOIN days_city_category d USING (id)
INNER JOIN real_estate."type" t USING (type_id)
WHERE id IN (SELECT * FROM filtered_id) -- фильтруем выбросы
	AND t."type" = 'город' -- фильтруем по заданию.
GROUP BY regions, act_segments --группируем по региону и сегментам активности
ORDER BY regions DESC, act_segments;

------------------------------------------------------------------------------------------------------------------------
-- Подзадача по объявлениям, которые еще не закрыты
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- делаем сте для категорий срока давности размещения объявления (отсчет от последней даты датасета) и категорий СПб-ЛенОбл
days_city_category AS (
	SELECT id, last_price, days_exposition,
		CASE WHEN '2019-05-03'::date - a.first_day_exposition <= 90 THEN '1 до 3 месяца назад'
			WHEN '2019-05-03'::date - a.first_day_exposition BETWEEN 91 AND 180 THEN '2 от 3х до 6х месяцев назад'
			WHEN '2019-05-03'::date - a.first_day_exposition BETWEEN 181 AND 365 THEN '3 от 6х месяцев до года назад'
			WHEN '2019-05-03'::date - a.first_day_exposition BETWEEN 366 AND 1480 THEN '4 от 1 до 4 лет назад'
			ELSE '5 Больше 4 лет назад'
			END AS time_segments,
		CASE WHEN c.city = 'Санкт-Петербург' THEN city
			ELSE 'ЛенОбл'
		END AS regions
	FROM real_estate.advertisement a
	FULL JOIN (SELECT id, city_id FROM real_estate.flats) f USING (id)
	FULL JOIN real_estate.city c USING (city_id)
	WHERE days_exposition IS NULL -- фильтр, оставляющий только не закрытые публикации
	)
-- Выведем статистику по регионам и сегментам срока давности публикации:
SELECT regions, time_segments, 
	COUNT(*) AS exposition_cnt, -- кол-во публикаций
	round(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC,2) AS share_total, --доля публикаций от общего числа публикаций
	round(COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY regions)::numeric,2) exp_region_share, -- доля публикаций от общего числа по региону
	round((SUM(last_price)/SUM(total_area))::numeric,2) AS avg_price_m2, -- срденяя цена м2
	round(AVG(total_area)::numeric,2) AS avg_total_area, -- средняя площадь жилья
	round(AVG(last_price)) AS avg_total_price,  -- средняя стоимость жилья
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,  -- медиана кол-ва комнат в жилье
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median, -- медиана кол-ва балконов в жилье
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS floor_median,  -- медиана этажа квартиры
	round(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ceiling_height)::numeric,2) AS ceiling_h_median -- медиана высоты потолка
FROM real_estate.flats f
INNER JOIN days_city_category d USING (id)
INNER JOIN real_estate."type" t USING (type_id)
WHERE id IN (SELECT * FROM filtered_id) -- фильтруем выбросы
	AND t."type" = 'город' -- фильтруем по заданию.
GROUP BY regions, time_segments --группируем по региону и сегментам активности
ORDER BY regions DESC, time_segments;

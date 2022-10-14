## 1.1. Выяснение требований к целевой витрине.

> Составьте документацию готовящейся витрины на основе заданных вами вопросов, добавив все необходимые детали.

Требования к витрине:

|Требование|Описание|
| --- | --- |
| Что сделать? | Построить витрину данных пользователей для RFM-классификации. Витрину нужно назвать dm_rfm_segments. Сохранить в базе в схеме analysis. |
| Зачем? | Для сегментации пользователей и определения направления маркетинговых усилий. |
| За какой период? | С начала 2022 года  |
| Обновления данных | Не требуются |
| Дополнительные требования | Учитывать только успешные заказы со статусом closed |

**Структура:** 

`user_id` - идентификатор пользователя

`receancy` - распределение клиентов по давности последнего заказа

`frequency` - распределение клиентов по частоте совершения заказов 

`monetary_value` - распределения клиентов по потраченной сумме  

## 1.2. Изучение структуры исходных данных.

> Подключитесь к базе данных и изучите структуру таблиц. Зафиксируйте, какие поля вы будете использовать для расчета витрины.

**Необходимые поля для расчёта:**

`user_id` - id.users 

`receancy` - orders_ts.orders

`frequency` - order_id.orders и функция count

`money_value` - payment.orders и функция sum

Для фильтра успешных заказов - status.orders

## 1.3. Анализ качество данных

> Изучите качество входных данных. Опишите, насколько качественные данные хранятся в источнике. Так же укажите, какие инструменты обеспечения качества данных были использованы в таблицах в схеме production

***Были просмотрены типы данных в колонках, все типы логически соответствуют необходимым данным. Проверены колонки на допустимость NULL значений, NULL допустимы только в колонке names в таблице users, но фактически NULL значений в этой колонке нет. Так же в таблицах присутствуют первичные ключи (во всех таблицах), внешние ключи для взаимосвязей таблиц и ограничения по цифирным значениям таких показателей как cost, price, discount, quantity. 
Вывод: качество данных допустимо для дальнейшего проведения работы.***


<details><summary>В таблицах используются следующие инструменты для обеспечения качества данных:</summary>

| Таблица | Объект | Инструмент | Для чего используют |
| --- | --- | --- | --- |
| production.products  | id is NOT NULL PRIMARY KEY | Первичный ключ | Обеспечивает уникальность записей о пользователях и исключает NULL |
| production.products  | price CHECK (price >= (0)::numeric) | Ограничение  | Обеспечивает цену в значении больше или равно нулю и тип данных numeric |
| production.orderstatuslog | id is NOT NULL PRIMARY KEY | Первичный ключ | Обеспечивает уникальность записей о заказах и исключает NULL |
| production.orderstatuslog | order_id, status_id UNIQUE | Ограничение  | Обеспечивает уникальность данных в  столбце среди всех строк таблицы |
| production.orderstatuslog | order_id, status_id FOREIGN KEY  | Внешний ключ | Обеспечивает совпадение значений в разных таблицах |
| production.orders | order_id is NOT NULL PRIMARY KEY | Первичный ключ | Обеспечивает уникальность записей о пользователях и исключает NULL |
| production.orders | CHECK cost = (payment + bonus_payment) | Ограничение  | Обеспечивает значение в колонке cost равное сумме колонок payment и bonus_payment |
| production.orderitems | id is PRIMARY KEY | Первичный ключ | Обеспечивает уникальность записей о заказах и исключает NULL |
| production.orderitems | order_id, product_id UNIQUE KEY | Ограничение  | Обеспечивает уникальность данных в  столбце среди всех строк таблицы |
| production.orderitems | CHECK discount >= (0)::numeric) AND (discount <= price | Ограничение  | Обеспечивает, что значение скидки не будет отрицательным, а так же не будет больше стоимости товара  |
| production.orderitems | CHECK price >= (0)::numeric | Ограничение  | Обеспечивает значение цены больше или равно нулю |
| production.orderitems | CHECK quantity > 0 | Ограничение  | Обеспечивает отсутствие отрицательных значение в количестве |
| production.orderitems | order_id, product_id FOREIGN KEY | Внешний ключ | Обеспечивает зависимость значений от таблиц orders и products  |
| production.users | id is NOT NULL PRIMARY KEY | Первичный ключ | Обеспечивает уникальность записей о пользователях и исключает NULL |
</details>
	
## **1.4. Подготовка витрины данных**

### 1.4.1. Создание VIEW для таблиц из базы production.

> Вас просят при расчете витрины обращаться только к объектам из схемы analysis. Чтобы не дублировать данные (данные находятся в этой же базе), вы решаете сделать view. Таким образом, View будут находиться в схеме analysis и вычитывать данные из схемы production.
>
> Напишите SQL-запросы для создания пяти VIEW (по одному на каждую таблицу) и выполните их. Для проверки предоставьте код создания VIEW.

```jsx
CREATE VIEW analysis.users AS
SELECT * FROM production.users;
```

```jsx
CREATE VIEW analysis.products AS
SELECT * FROM production.products;
```

```jsx
CREATE VIEW analysis.orderstatuslog AS
SELECT * FROM production.orderstatuslog;
```

```jsx
CREATE VIEW analysis.orders AS
SELECT * FROM production.orders;
```

```jsx
CREATE VIEW analysis.orderitems AS
SELECT * FROM production.orderitems;
```

### 1.4.2. Написание DDL-запроса для создания витрины.

> Далее вам необходимо создать витрину. Напишите CREATE TABLE запрос и выполните его на предоставленной базе данных в схеме analysis.

```jsx
CREATE TABLE IF NOT EXISTS analysis.dm_rfm_segments (
  user_id INT NOT NULL PRIMARY KEY,
  recency INT NOT NULL CHECK(recency > 0 AND recency <= 5),
  frequency INT NOT NULL CHECK(frequency > 0 AND frequency <= 5),
  money_value INT NOT NULL CHECK(money_value > 0 AND money_value <= 5)
)
```

### 1.4.3. Написание SQL запросов для заполнения витрины

> Напишите SQL-запрос для заполнения витрины
> Реализуйте расчёт витрины на языке SQL и заполните таблицу, созданную в предыдущем пункте.
>
>Рассчитайте витрину поэтапно. Сначала заведите таблицы под каждый показатель:

```jsx
CREATE TABLE analysis.tmp_rfm_recency (
user_id INT NOT NULL PRIMARY KEY,
recency INT NOT NULL CHECK(recency >= 1 AND recency <= 5)
);
CREATE TABLE analysis.tmp_rfm_frequency (
user_id INT NOT NULL PRIMARY KEY,
frequency INT NOT NULL CHECK(frequency >= 1 AND frequency <= 5)
);
CREATE TABLE analysis.tmp_rfm_monetary_value (
user_id INT NOT NULL PRIMARY KEY,
monetary_value INT NOT NULL CHECK(monetary_value >= 1 AND monetary_value <= 5)
);
```

Запрос для заполнения таблицы `analysis.tmp_rfm_recency`:

```jsx
WITH closed AS (
	SELECT user_id, max(order_ts) as last_time
	FROM analysis.orders o
	WHERE status = 4
	GROUP BY user_id),
all_users as (
	SELECT DISTINCT user_id 
	FROM orders
	)
INSERT INTO tmp_rfm_recency
SELECT a.user_id,  
	   ntile(5) OVER (ORDER BY coalesce(last_time, '2010-01-01 00:00:00.000' ) ASC) AS receancy 
FROM all_users a
	LEFT JOIN closed c ON c.user_id = a.user_id 
GROUP BY a.user_id, c.last_time;
```

Запрос для заполнения таблицы `analysis.tmp_rfm_frequency`

```jsx
WITH closed AS (
	SELECT user_id, 
		   COUNT(*) AS qty
	FROM analysis.orders o
	WHERE status = 4
	GROUP BY user_id
	),
all_users AS (
	SELECT DISTINCT user_id 
	FROM orders
	)	
INSERT INTO analysis.tmp_rfm_frequency
SELECT a.user_id, 
	   ntile(5) OVER (ORDER BY coalesce(qty, 0) ASC) AS frequency
FROM all_users a
	 LEFT JOIN closed c ON c.user_id = a.user_id 
GROUP BY a.user_id, qty;
```

Запрос для заполнения таблицы `analysis.tmp_rfm_monetary_value`

```jsx
WITH closed AS ( 
	SELECT user_id, 
		   SUM(payment) as total_payment
	FROM analysis.orders o
	WHERE status = 4
	GROUP BY user_id
	),
all_users as (
	SELECT DISTINCT user_id FROM orders
	)
INSERT INTO analysis.tmp_rfm_monetary_value
SELECT a.user_id,  
	   ntile(5) OVER (ORDER BY coalesce(total_payment, 0 ) ASC) AS moneytary_value
FROM all_users a
	 LEFT JOIN closed c ON c.user_id = a.user_id 
GROUP BY a.user_id, c.total_payment;
```

> Запрос, который на основе данных, подготовленных в таблицах `analysis.tmp_rfm_recency`
, `analysis.tmp_rfm_frequency` и `analysis.tmp_rfm_monetary_value`заполнит витрину `analysis.dm_rfm_segments:`

```jsx
/*Вставка в общую таблицу*/
INSERT INTO analysis.dm_rfm_segments
SELECT DISTINCT o.user_id, recency, frequency, monetary_value FROM analysis.orders o
    LEFT JOIN analysis.tmp_rfm_frequency f ON f.user_id = o.user_id
    LEFT JOIN analysis.tmp_rfm_recency r ON r.user_id = f.user_id
    LEFT JOIN analysis.tmp_rfm_monetary_value m ON m.user_id = r.user_id
```

```jsx
SELECT * FROM dm_rfm_segments
ORDER BY user_id
LIMIT 10;
```

| user_id | recency | frequency | money_value |
| --- | --- | --- | --- |
| 0 | 1 | 3 | 4 |
| 1 | 4 | 3 | 3 |
| 2 | 2 | 3 | 5 |
| 3 | 2 | 3 | 3 |
| 4 | 4 | 3 | 3 |
| 5 | 5 | 5 | 5 |
| 6 | 1 | 3 | 5 |
| 7 | 4 | 3 | 2 |
| 8 | 1 | 1 | 3 |
| 9 | 1 | 2 | 2 |

---

## **2. Доработка представлений**

> Через некоторое время вам пишет менеджер и сообщает, что витрина больше не собирается. Вы начинаете разбираться, в чём причина, и выясняете, что бэкенд-разработчики  приложения обновили структуру данных в схеме `production`: в таблице `Orders` больше нет поля статуса. А это поле необходимо, потому что для анализа нужно выбрать только успешно выполненные заказы со статусом `closed`.
>
>Вместо поля с одним статусом разработчики добавили таблицу для журналирования всех изменений статусов заказов — `production.OrderStatusLog`.

Структура таблицы `production.OrderStatusLog`:

- `id` — синтетический автогенерируемый идентификатор записи,
- `order_id` — идентификатор заказа, внешний ключ на таблицу `production.Orders`,
- `status_id` — идентификатор статуса, внешний ключ на таблицу статусов заказов `production.OrderStatuses`,
- `dttm` — дата и время получения заказом этого статуса.

>Чтобы ваш скрипт по расчёту витрины продолжил работать, вам необходимо внести изменения в то, как формируется представление `analysis.Orders`: вернуть в него поле `status`. Значение в этом поле должно соответствовать последнему по времени статусу из таблицы `production.OrderStatusLog`.
```jsx
--Удаление старой витрины 
DROP VIEW analysis.orders;

--Обновление витрины
CREATE OR REPLACE VIEW analysis.orders AS
SELECT ord.order_id, 
	   order_ts, 
	   user_id, 
	   payment, 
	   new_status 
FROM production.orders ord 
	INNER JOIN (
		SELECT DISTINCT order_id, 
			 first_value(status_id) OVER (PARTITION BY order_id ORDER BY dttm DESC) AS new_status
		FROM production.orderstatuslog o) AS query_in ON query_in.order_id = ord.order_id;
```

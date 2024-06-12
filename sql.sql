set schema 'library';
-- выбрать все книги (не экземпляры книг) одного автора
SELECT b.id, b.title, b.isbn
FROM book b
         JOIN books_authors ba ON b.id = ba.book_id
         JOIN author a ON ba.author_id = a.id
WHERE a.first_name = 'George';

/*
 выбрать все книги (не экземпляры книг) одного автора,
 написанные в соавторстве с другими авторами
 */
SELECT b.id, b.title, b.isbn
FROM book b
         JOIN books_authors ba1 ON b.id = ba1.book_id
         JOIN author a1 ON ba1.author_id = a1.id
         JOIN books_authors ba2 ON b.id = ba2.book_id
         JOIN author a2 ON ba2.author_id = a2.id
WHERE a1.first_name = 'Harper'
  AND (a1.id != a2.id);

/*
 выбрать все экземпляры определённой книги (по названию и автору/авторам),
 которые есть в библиотеке (не выданы и не списаны)
 */

SELECT bc.id
FROM book_copy bc
         JOIN book b ON bc.book_id = b.id
WHERE b.title = 'The Great Gatsby'
    AND bc.status = 'Available'
    AND b.id IN (SELECT ba.book_id
                 FROM books_authors ba
                          JOIN author a ON ba.author_id = a.id
                 WHERE a.first_name = 'F. Scott')
   OR b.id IN (SELECT ba.book_id
               FROM books_authors ba
                        JOIN author a ON ba.author_id = a.id
               WHERE a.first_name = 'George');

/*
 выбрать все экземпляры книг, списанные за последний квартал
 */

SELECT *
FROM book_disposal bd
where disposal_date between '2023-06-01' and '2023-06-14';


/*
 выбрать 10 наиболее популярных книг за последний квартал с сортировкой по популярности
 */
SELECT b.title
FROM book b
         JOIN book_copy bc ON b.id = bc.book_id
         JOIN book_lending bl ON bl.copy_id = bc.id
WHERE bl.lend_date between '2023-05-10' and '2023-08-12'
GROUP BY b.title
ORDER BY count(bl.id) desc
LIMIT 10;

-- выбрать по 10 наиболее популярных книг по всем категориям за последний квартал с сортировкой по популярности
SELECT b.title
FROM book b
         JOIN book_copy bc ON b.id = bc.book_id
         JOIN book_lending bl ON bl.copy_id = bc.id
WHERE bl.lend_date between '2023-05-10' and '2023-08-12'
GROUP BY b.title
ORDER BY count(bl.id) desc
LIMIT 10;

--выбрать 10 наиболее популярных авторов за последний квартал с сортировкой по популярности
SELECT concat(a.first_name, ' ', a.last_name) as name, count(bl.id)
FROM author a
         JOIN books_authors ba ON ba.author_id = a.id
         JOIN book b ON ba.book_id = b.id
         JOIN book_copy bc ON b.id = bc.book_id
         JOIN book_lending bl ON bl.copy_id = bc.id
WHERE bl.lend_date between date_trunc('quarter', current_date) - interval '3 month'
          and date_trunc('quarter', current_date)
GROUP BY a.first_name, a.last_name
ORDER BY count(bl.id) desc
LIMIT 10;

-- выбрать 10 наиболее популярных авторов за последний квартал с сортировкой по популярности и отображением до трёх самых популярных книг по каждому автору
-- NOT DONE
with author_popularity as(
SELECT concat(a.first_name, ' ', a.last_name) as name, b.title,
       row_number() over (partition by concat(a.first_name, ' ', a.last_name) order by count(bl.id)) as row_num
FROM author a
         JOIN books_authors ba ON ba.author_id = a.id
         JOIN book b ON ba.book_id = b.id
         JOIN book_copy bc ON b.id = bc.book_id
         JOIN book_lending bl ON bl.copy_id = bc.id
WHERE bl.lend_date between date_trunc('quarter', current_date) - interval '3 month'
          and date_trunc('quarter', current_date)
GROUP BY a.first_name, a.last_name, b.title

ORDER BY count(bl.id) desc
LIMIT 10)
SELECT name, string_agg(title, ', ') FROM author_popularity
WHERE row_num in (1, 2, 3)
GROUP BY name;
-- найти популярные книги каждого писателя в лимите трёх и вывести

--выбрать 100 наиболее активных читателей (по количеству взятых книг)
SELECT concat(r.first_name, ' ', r.last_name) as name, count(bl.id)
FROM reader r
         JOIN reader_ticket rt ON r.id = rt.reader_id
         JOIN book_lending bl ON rt.id = bl.ticket_id
GROUP BY r.first_name, r.last_name
ORDER BY count(bl.id) desc
LIMIT 100;

-- - выбрать 100 наиболее безответственных читателей, у которых больше всех просроченных возвратов
SELECT concat(r.first_name, ' ', r.last_name) as name
FROM book_reception br
         JOIN book_lending bl ON bl.copy_id = br.copy_id
         JOIN reader_ticket rt ON bl.ticket_id = rt.id
         JOIN reader r ON rt.reader_id = r.id
where br.return_date > bl.due_date
GROUP BY r.first_name, r.last_name
ORDER BY count(bl.id) DESC
LIMIT 100;

--выбрать 100 наиболее безответственных читателей, у которых больше всех утерь книг
WITH lost_books AS (SELECT bl.copy_id, bl.ticket_id
                    FROM book_lending bl
                    EXCEPT
                    SELECT br.copy_id, br.ticket_id
                    FROM book_reception br)
SELECT concat(r.first_name, ' ', r.last_name) as name
FROM lost_books
         JOIN book_disposal bd ON bd.copy_id = lost_books.copy_id
         JOIN reader_ticket rt ON rt.id = lost_books.ticket_id
         JOIN reader r ON r.id = rt.reader_id
GROUP BY r.first_name, r.last_name
ORDER BY count(bd.copy_id) desc
LIMIT 100;

--выбрать количество выдач (возвратов) книг по дням за последний месяц
SELECT count(id) as count_reception
FROM book_reception br
WHERE br.return_date between '2023-06-10' and '2023-06-12';

--выбрать самые пустующие полки / стеллажи
SELECT s.rack_id, s.id AS shelf_id, s.position, count(bc.book_id)
FROM shelf s JOIN book_copy bc ON s.id = bc.shelf_id
WHERE bc.status = 'Available'
GROUP BY s.id
ORDER BY count(bc.book_id) desc
LIMIT 5;


--посчитать количество свободных мест для книг
with count_books as (
    SELECT count(bc.book_id) as count
    FROM shelf s JOIN book_copy bc ON s.id = bc.shelf_id
    WHERE bc.status = 'Available'
    GROUP BY s.id
)
SELECT (SELECT sum(shelf.capacity) FROM shelf) -
(SELECT sum(count_books.count) FROM count_books) AS free_space;

--посчитать количество всех книг / экземпляров книг / авторов / книг по каждому автору / экзмпляров книг по каждому автору /
SELECT count(*) as count_books FROM book;

SELECT count(*) as count_books_copy FROM book_copy;

SELECT count(*) as authors FROM author;

SELECT concat(a.first_name, ' ', a.last_name) as full_name, count(ba.book_id) as count_books
FROM author a JOIN books_authors ba ON a.id = ba.author_id
GROUP BY a.first_name, a.last_name
ORDER BY count_books desc ;

explain analyze SELECT concat(a.first_name, ' ', a.last_name) as full_name, count(bc.id) as count_books_copy
FROM author a JOIN books_authors ba ON a.id = ba.author_id
JOIN book_copy bc ON bc.book_id = ba.book_id
GROUP BY a.first_name, a.last_name
ORDER BY count_books_copy desc ;















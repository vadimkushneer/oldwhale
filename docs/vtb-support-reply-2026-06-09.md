# Ответ в поддержку VTB KZ (sandbox)

Дата подготовки: 2026-06-09  
Контекст: ответ на запрос поддержки по интеграции eCommerce (redirect) в sandbox.

---

Здравствуйте.

## 1. Уточнение по интеграции

Да, понимание верное: мы используем **интеграцию через редирект на платёжную страницу** по схеме из документации  
https://sandbox.vtb-bank.kz/ru/integration/structure/redirect-integration.html

Наш поток:

1. **Бэкенд** (`oldwhale-backend`) вызывает `POST …/payment/rest/register.do` (sandbox: `https://vtbkz.rbsuat.com/payment/rest/register.do`).
2. Из ответа берём `orderId` и **`formUrl`**.
3. **Фронтенд** перенаправляет браузер плательщика на `formUrl` (hosted payment page).
4. После оплаты/отмены VTB возвращает пользователя на наш `returnUrl` / `failUrl`.
5. Финальный статус и зачисление кредитов подтверждаем **только через `getOrderStatusExtended.do`** (и опционально callback), а не по редиректу браузера.

Текущие публичные URL (production):

| Параметр | Значение |
|----------|----------|
| Сайт | `https://oldwhale.net` |
| `returnUrl` / `failUrl` | `https://oldwhale.net/payment/return/{paymentId}` |
| `dynamicCallbackUrl` | `https://oldwhale.net/api/payments/vtb/callback` |
| Валюта | `398` (KZT) |
| Сумма | `amount = credits × 100` (1 OWK = 1 KZT, в тийынах) |
| Язык страницы | `ru` |
| API sandbox | `https://vtbkz.rbsuat.com/payment/rest/` |
| Мерчант (sandbox) | `Oldwhale` |

**Важно:** наш бэкенд **не вызывает** `getSessionStatus.do`. Этот метод вызывается **внутренним JS платёжной страницы VTB** при её инициализации (`MDORDER` в теле POST на `../../rest/getSessionStatus.do` → `/payment/rest/getSessionStatus.do`).

---

## 2. Проверка вашего тестового заказа

Ссылка:  
`https://vtbkz.rbsuat.com/payment/merchants/ecom/payment.html?mdOrder=3b84dcbc-92ea-78e4-9280-c3a900dec74d&language=ru`

**`mdOrder`:** `3b84dcbc-92ea-78e4-9280-c3a900dec74d`

### HTML-страница

- `GET payment.html` → **HTTP 200** (страница отдаётся).

### `getSessionStatus.do` (как вызывает браузер со страницы оплаты)

```http
POST https://vtbkz.rbsuat.com/payment/rest/getSessionStatus.do
Content-Type: application/x-www-form-urlencoded

MDORDER=3b84dcbc-92ea-78e4-9280-c3a900dec74d&language=ru
```

**Ответ (HTTP 200):**

```json
{
  "redirect": "https://yandex.kz/?orderId=3b84dcbc-92ea-78e4-9280-c3a900dec74d&lang=ru",
  "orderExpired": true,
  "merchantInfo": { "custom": false }
}
```

Ошибки **HTTP 400 / `errorCode: 7` на этом заказе сейчас не воспроизводится**, если передавать корректное поле `MDORDER`.  
При передаче `orderId` вместо `MDORDER` получаем:

```json
HTTP 400
{"errorCode":5,"errorMessage":"Отсутствует обязательное поле [MDORDER]"}
```

### `getOrderStatusExtended.do`

```json
HTTP 200
{
  "errorCode": "0",
  "errorMessage": "Успешно",
  "orderNumber": "TEST052626-1",
  "orderStatus": 6,
  "actionCode": -2014,
  "actionCodeDescription": "Операция отклонена. Проверьте введённые данные, достаточность средств на карте и повторите операцию.",
  "amount": 100,
  "currency": "398",
  "orderDescription": "TEST2"
}
```

**Вывод по вашему заказу:** сессия **истекла** (`orderExpired: true`), в статусе заказ **отклонён** (`orderStatus: 6`). Вероятная причина проблем на странице — **просроченная/завершённая сессия**, а не ошибка нашей интеграции `register.do`.

---

## 3. Наш аналогичный заказ с `sessionTimeoutSecs = 18000`

Создан нами через `register.do` с теми же production URL (`https://oldwhale.net`), суммой **100 KZT (100 OWK)** и `sessionTimeoutSecs=18000` (5 часов).

### Параметры `register.do`

| Поле | Значение |
|------|----------|
| `orderNumber` | `owb9be71d9bbdf792e64bcb52ed814` |
| `amount` | `10000` (100.00 KZT) |
| `currency` | `398` |
| `returnUrl` / `failUrl` | `https://oldwhale.net/payment/return/...` |
| `dynamicCallbackUrl` | `https://oldwhale.net/api/payments/vtb/callback` |
| `sessionTimeoutSecs` | `18000` |
| `language` | `ru` |
| `description` | `OldWhale VTB support test 100 OWK` |

### Ответ `register.do`

```json
HTTP 200
{
  "orderId": "e8c78841-ca18-78de-8aad-857000dec74d",
  "formUrl": "https://vtbkz.rbsuat.com/payment/merchants/ecom/payment.html?mdOrder=e8c78841-ca18-78de-8aad-857000dec74d&language=ru"
}
```

### `formUrl` для параллельной проверки

```
https://vtbkz.rbsuat.com/payment/merchants/ecom/payment.html?mdOrder=e8c78841-ca18-78de-8aad-857000dec74d&language=ru
```

### `getSessionStatus.do` сразу после создания

```json
HTTP 200
{
  "remainingSecs": 17980,
  "orderNumber": "owb9be71d9bbdf792e64bcb52ed814",
  "amount": "100.00 KZT",
  "description": "OldWhale VTB support test 100 OWK",
  "backUrl": "https://oldwhale.net/payment/return/test-e383a1bb59d7ab59?orderId=e8c78841-ca18-78de-8aad-857000dec74d&lang=ru",
  "orderExpired": false,
  "merchantInfo": {
    "merchantUrl": "https://Oldwhale.net",
    "merchantFullName": "Oldwhale",
    "merchantLogin": "Oldwhale",
    "merchantInn": "200940013114"
  }
}
```

**Ошибки в консоли (эквивалент Network tab) на свежем заказе — нет.** `getSessionStatus.do` отвечает **200**, страница оплаты открывается (**HTTP 200**).

### `getOrderStatusExtended.do`

```json
HTTP 200
{
  "errorCode": "0",
  "orderStatus": 0,
  "orderNumber": "owb9be71d9bbdf792e64bcb52ed814",
  "amount": 10000,
  "currency": "398"
}
```

(`orderStatus: 0` — заказ создан, ожидает оплаты.)

---

## Дополнительно

- В нашем приложении по умолчанию `sessionTimeoutSecs = 1200`; для этого теста явно передали **18000** по запросу поддержки.
- Для диагностики статуса оплаты мы опираемся на **`getOrderStatusExtended.do`**, как рекомендует REST-документация; `getSessionStatus.do` — внутренний API платёжной страницы VTB.
- Если на стороне VTB воспроизводится `errorCode: 7 / System error` на **активной** сессии — просим указать, при каких именно параметрах запроса это происходит; на свежей сессии (`e8c78841-…`) проблема **не воспроизводится**.

С уважением,  
команда OldWhale

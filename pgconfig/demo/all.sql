BEGIN;

CREATE SCHEMA IF NOT EXISTS trading;

CREATE TABLE trading.user_symbols (
    user_id INTEGER NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    balance NUMERIC(10, 4) NOT NULL,
    quantity NUMERIC(10, 4) NOT NULL,
    last_updated TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, symbol)
);

CREATE TABLE trading.orders (
    order_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    order_type VARCHAR(10) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    quantity NUMERIC(10, 4) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL
);

CREATE TABLE trading.events (
    event_id SERIAL PRIMARY KEY,
    event_type VARCHAR(10) NOT NULL,
    user_id INTEGER NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    quantity NUMERIC(10, 4) NOT NULL,
    timestamp TIMESTAMP NOT NULL
);

CREATE SCHEMA IF NOT EXISTS payment;

CREATE TYPE payment.gateway AS ENUM ('trading', 'cashier');

CREATE TABLE payment.payment (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    foreign_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    gateway payment.gateway NOT NULL, 
    amount NUMERIC(10, 4) NOT NULL,
    balance NUMERIC(10, 4) NOT NULL
);

CREATE OR REPLACE FUNCTION payment.process_deposit(
    user_id INTEGER,
    amount NUMERIC(10, 4)
) RETURNS VOID AS $$
BEGIN
    UPDATE payment.payment
    SET balance = balance + amount
    WHERE user_id = process_deposit.user_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION payment.process_payout(
    user_id INTEGER, 
    amount NUMERIC(10, 4)
) RETURNS VOID AS $$
BEGIN
    UPDATE payment.payment
    SET balance = balance - amount
    WHERE user_id = process_withdrawal.user_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION payment.process_trade_payment(
    user_id INTEGER,
    amount NUMERIC(10, 4), 
    trade_type VARCHAR(10)
) RETURNS VOID AS $$
BEGIN
    IF trade_type = 'buy' THEN
        UPDATE payment.payment
        SET balance = balance - amount
        WHERE user_id = process_trade_payment.user_id;
    ELSIF trade_type = 'sell' THEN
        UPDATE payment.payment
        SET balance = balance + amount
        WHERE user_id = process_trade_payment.user_id;
    END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION payment.create_payment(
    user_id INTEGER,
    foreign_id INTEGER,
    gateway payment.gateway,
    amount NUMERIC(10, 4),
    balance NUMERIC(10, 4)
) RETURNS INTEGER AS $$
DECLARE
    new_id INTEGER;
BEGIN
    BEGIN
        INSERT INTO payment.payment (user_id, foreign_id, gateway, amount, balance)
        VALUES (user_id, foreign_id, gateway, amount, balance)
        RETURNING id INTO new_id;
    EXCEPTION
        WHEN others THEN
            RAISE NOTICE 'Failed to create payment: %', SQLERRM;
            new_id := -1;
    END;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE SCHEMA IF NOT EXISTS reporting;

COMMIT;

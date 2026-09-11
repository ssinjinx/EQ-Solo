import {sql} from 'drizzle-orm';
import {sqliteTable,text,integer,uniqueIndex,index} from 'drizzle-orm/sqlite-core';
export const profiles=sqliteTable('profiles',{id:text('id').primaryKey(),data:text('data').notNull(),version:integer('version').notNull().default(0)});
export const matches=sqliteTable('matches',{id:text('id').primaryKey(),host:text('host').notNull(),guest:text('guest'),state:text('state').notNull(),version:integer('version').notNull().default(0)});
export const inventory=sqliteTable('inventory',{id:text('id').primaryKey(),owner:text('owner').notNull(),card:text('card').notNull()},t=>[index('inventory_owner').on(t.owner)]);
export const trades=sqliteTable('trades',{id:text('id').primaryKey(),maker:text('maker').notNull(),offered:text('offered').notNull(),wanted:text('wanted').notNull(),status:text('status').notNull().default('open')},t=>[uniqueIndex('one_open_offer_per_card').on(t.offered).where(sql`${t.status} = 'open'`)]);
export const packAccounts=sqliteTable('pack_accounts',{owner:text('owner').primaryKey(),starterClan:text('starter_clan')});
export const packs=sqliteTable('packs',{id:text('id').primaryKey(),owner:text('owner').notNull(),tier:text('tier').notNull(),contents:text('contents'),openingKey:text('opening_key'),openedAt:integer('opened_at')},t=>[index('packs_owner').on(t.owner)]);

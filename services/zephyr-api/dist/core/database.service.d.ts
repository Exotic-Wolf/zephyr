import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { type QueryResult, type QueryResultRow } from 'pg';
export declare class DatabaseService implements OnModuleInit, OnModuleDestroy {
    private readonly logger;
    private pool;
    onModuleInit(): void;
    onModuleDestroy(): Promise<void>;
    isEnabled(): boolean;
    query<T extends QueryResultRow = QueryResultRow>(sql: string, params?: unknown[]): Promise<QueryResult<T>>;
    ping(): Promise<void>;
    private ensureSchema;
}

import { DatabaseService } from '../core/database.service';
export declare class HealthController {
    private readonly databaseService;
    constructor(databaseService: DatabaseService);
    live(): {
        status: 'ok';
        timestamp: string;
    };
    ready(): Promise<{
        status: 'ok';
        storage: 'postgres' | 'in-memory';
        timestamp: string;
    }>;
}

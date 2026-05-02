import { StoreService } from '../core/store.service';
import type { LiveFeedCard } from '../core/store.service';
export declare class FeedController {
    private readonly storeService;
    constructor(storeService: StoreService);
    listLiveFeed(authorization: string | undefined, limit: number): Promise<LiveFeedCard[]>;
}

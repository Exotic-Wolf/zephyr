import { StoreService } from '../core/store.service';
import type { UserProfile } from '../core/store.service';
import { UpdateMeDto } from './dto/update-me.dto';
export declare class UsersController {
    private readonly storeService;
    constructor(storeService: StoreService);
    getMe(authorization?: string): Promise<UserProfile>;
    updateMe(authorization: string | undefined, body: UpdateMeDto): Promise<UserProfile>;
}

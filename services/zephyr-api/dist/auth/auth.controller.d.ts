import { StoreService } from '../core/store.service';
import { GuestLoginDto } from './dto/guest-login.dto';
import { GoogleLoginDto } from './dto/google-login.dto';
import { AppleLoginDto } from './dto/apple-login.dto';
export declare class AuthController {
    private readonly storeService;
    constructor(storeService: StoreService);
    guestLogin(body: GuestLoginDto): Promise<{
        accessToken: string;
        user: unknown;
    }>;
    googleLogin(body: GoogleLoginDto): Promise<{
        accessToken: string;
        user: unknown;
    }>;
    appleLogin(body: AppleLoginDto): Promise<{
        accessToken: string;
        user: unknown;
    }>;
}

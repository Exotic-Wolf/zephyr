import { DatabaseService } from './database.service';
export interface UserProfile {
    id: string;
    displayName: string;
    avatarUrl: string | null;
    bio: string | null;
    createdAt: string;
}
export interface Room {
    id: string;
    hostUserId: string;
    title: string;
    audienceCount: number;
    status: 'live';
    createdAt: string;
}
export interface LiveFeedCard {
    roomId: string;
    title: string;
    audienceCount: number;
    hostUserId: string;
    hostDisplayName: string;
    hostAvatarUrl: string | null;
    startedAt: string;
}
export declare class StoreService {
    private readonly databaseService?;
    constructor(databaseService?: DatabaseService | undefined);
    private readonly logger;
    private readonly googleClient;
    private readonly users;
    private readonly sessions;
    private readonly rooms;
    private readonly googleSubjectToUserId;
    private readonly appleSubjectToUserId;
    issueGuestSession(displayName?: string): Promise<{
        accessToken: string;
        user: UserProfile;
    }>;
    issueGoogleSession(idToken: string): Promise<{
        accessToken: string;
        user: UserProfile;
    }>;
    issueAppleSession(idToken: string, profileHints?: {
        givenName?: string;
        familyName?: string;
        email?: string;
    }): Promise<{
        accessToken: string;
        user: UserProfile;
    }>;
    getUserFromAuthHeader(authorization?: string): Promise<UserProfile>;
    updateUser(userId: string, updates: {
        displayName?: string;
        avatarUrl?: string | null;
        bio?: string | null;
    }): Promise<UserProfile>;
    listRooms(): Promise<Room[]>;
    listLiveFeed(limit?: number): Promise<LiveFeedCard[]>;
    createRoom(hostUserId: string, title: string): Promise<Room>;
    joinRoom(roomId: string): Promise<Room>;
    private toUserProfile;
    private toRoom;
    private getGoogleAudiences;
    private signJwt;
    private verifyJwt;
    private getJwtSecret;
    private verifyAppleIdToken;
}

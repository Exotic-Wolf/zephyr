import { StoreService } from '../core/store.service';
import type { Room } from '../core/store.service';
import { CreateRoomDto } from './dto/create-room.dto';
export declare class RoomsController {
    private readonly storeService;
    constructor(storeService: StoreService);
    listRooms(): Promise<Room[]>;
    createRoom(authorization: string | undefined, body: CreateRoomDto): Promise<Room>;
    joinRoom(authorization: string | undefined, roomId: string): Promise<Room>;
}

import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { StoreService } from './store.service';

describe('StoreService', () => {
  let storeService: StoreService;

  beforeEach(() => {
    storeService = new StoreService();
  });

  it('creates guest session and resolves user from bearer token', async () => {
    const session = await storeService.issueGuestSession('wolf');
    const user = await storeService.getUserFromAuthHeader(`Bearer ${session.accessToken}`);

    expect(user.id).toBe(session.user.id);
    expect(user.displayName).toBe('wolf');
  });

  it('rejects invalid profile displayName update', async () => {
    const session = await storeService.issueGuestSession('wolf');

    await expect(
      storeService.updateUser(session.user.id, { displayName: 'x' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('creates and joins room', async () => {
    const session = await storeService.issueGuestSession('wolf');
    const room = await storeService.createRoom(session.user.id, 'Late Night Talk');
    const joinedRoom = await storeService.joinRoom(room.id);

    expect(joinedRoom.audienceCount).toBe(2);
    const rooms = await storeService.listRooms();
    expect(rooms[0].id).toBe(room.id);
  });

  it('rejects missing auth header', async () => {
    await expect(storeService.getUserFromAuthHeader(undefined)).rejects.toThrow(
      UnauthorizedException,
    );
  });
});
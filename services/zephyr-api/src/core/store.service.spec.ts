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

  it('allows one user to be both caller and receiver', async () => {
    const session = await storeService.issueGuestSession('wolf_dual');

    const startedSession = await storeService.startCallSession(session.user.id, {
      mode: 'direct',
      receiverUserId: session.user.id,
      directRateCoinsPerMinute: 2100,
    });

    expect(startedSession.callerUserId).toBe(session.user.id);
    expect(startedSession.receiverUserId).toBe(session.user.id);

    const walletBeforeTick = await storeService.getWalletSummary(session.user.id);
    const tickResult = await storeService.tickCallSession(
      session.user.id,
      startedSession.id,
      10,
    );
    const walletAfterTick = await storeService.getWalletSummary(session.user.id);

    expect(tickResult.chargedCoins).toBeGreaterThan(0);
    expect(tickResult.receiverSpark).toBeGreaterThan(0);
    expect(walletAfterTick.coinBalance).toBe(
      walletBeforeTick.coinBalance - tickResult.chargedCoins,
    );

    const endedSession = await storeService.endCallSession(
      session.user.id,
      startedSession.id,
      'caller_ended',
    );

    expect(endedSession.status).toBe('ended');
  });

  it('charges caller and awards spark to receiver', async () => {
    const callerSession = await storeService.issueGuestSession('caller_user');
    const receiverSession = await storeService.issueGuestSession('receiver_user');

    const callerWalletBefore = await storeService.getWalletSummary(callerSession.user.id);
    const receiverWalletBefore = await storeService.getWalletSummary(
      receiverSession.user.id,
    );

    const startedSession = await storeService.startCallSession(callerSession.user.id, {
      mode: 'direct',
      receiverUserId: receiverSession.user.id,
      directRateCoinsPerMinute: 2100,
    });

    const tickResult = await storeService.tickCallSession(
      callerSession.user.id,
      startedSession.id,
      10,
    );

    const callerWalletAfter = await storeService.getWalletSummary(callerSession.user.id);
    const receiverWalletAfter = await storeService.getWalletSummary(
      receiverSession.user.id,
    );

    expect(callerWalletAfter.coinBalance).toBe(
      callerWalletBefore.coinBalance - tickResult.chargedCoins,
    );
    expect(receiverWalletAfter.sparkBalance).toBeGreaterThan(
      receiverWalletBefore.sparkBalance,
    );
    expect(receiverWalletAfter.coinBalance).toBe(receiverWalletBefore.coinBalance);
  });

  it('prevents a busy caller from starting another live call', async () => {
    const caller = await storeService.issueGuestSession('caller_busy');
    const receiverOne = await storeService.issueGuestSession('receiver_one');
    const receiverTwo = await storeService.issueGuestSession('receiver_two');

    await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiverOne.user.id,
      directRateCoinsPerMinute: 2100,
    });

    await expect(
      storeService.startCallSession(caller.user.id, {
        mode: 'direct',
        receiverUserId: receiverTwo.user.id,
        directRateCoinsPerMinute: 2100,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('prevents calling a receiver who is already in a live call', async () => {
    const callerOne = await storeService.issueGuestSession('caller_one');
    const callerTwo = await storeService.issueGuestSession('caller_two');
    const busyReceiver = await storeService.issueGuestSession('busy_receiver');

    await storeService.startCallSession(callerOne.user.id, {
      mode: 'direct',
      receiverUserId: busyReceiver.user.id,
      directRateCoinsPerMinute: 2100,
    });

    await expect(
      storeService.startCallSession(callerTwo.user.id, {
        mode: 'direct',
        receiverUserId: busyReceiver.user.id,
        directRateCoinsPerMinute: 2100,
      }),
    ).rejects.toThrow(BadRequestException);
  });
});
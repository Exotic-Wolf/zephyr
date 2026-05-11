import {
  OnGatewayConnection,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import type { Message } from '../core/store.service';

/**
 * Real-time gateway for direct messages.
 *
 * Client must emit `chat:join` with their userId after connecting.
 * Events emitted:
 *   chat:message  { message: Message }  → sent to sender + receiver rooms
 */
@WebSocketGateway({ cors: { origin: '*' }, namespace: '/chat' })
export class MessagesGateway implements OnGatewayInit, OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  afterInit() {
    console.log('[MessagesGateway] WebSocket gateway initialised on /chat');
  }

  handleConnection(client: Socket) {
    // Client sends userId via query param on connect for immediate room join
    const userId = client.handshake.query['userId'] as string | undefined;
    if (userId) {
      void client.join(userId);
    }
  }

  @SubscribeMessage('chat:join')
  handleJoin(
    @MessageBody() userId: string,
    @ConnectedSocket() client: Socket,
  ): void {
    void client.join(userId);
  }

  emitNewMessage(message: Message): void {
    this.server.to(message.receiverId).emit('chat:message', { message });
    this.server.to(message.senderId).emit('chat:message', { message });
  }
}

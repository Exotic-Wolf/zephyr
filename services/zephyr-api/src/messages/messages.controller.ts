import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  DefaultValuePipe,
  ParseIntPipe,
} from '@nestjs/common';
import { StoreService } from '../core/store.service';
import { FcmService } from '../core/fcm.service';
import type { Conversation, Message } from '../core/store.service';
import { SendMessageDto } from './dto/send-message.dto';
import { MessagesGateway } from './messages.gateway';

@Controller('v1/messages')
export class MessagesController {
  constructor(
    private readonly storeService: StoreService,
    private readonly messagesGateway: MessagesGateway,
    private readonly fcmService: FcmService,
  ) {}

  @Post('device-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async registerDeviceToken(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { token: string },
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.upsertDeviceToken(me.id, body.token);
  }

  @Delete('device-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unregisterDeviceToken(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { token: string },
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.deleteDeviceToken(me.id, body.token);
  }

  @Post()
  async sendMessage(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: SendMessageDto,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const message = await this.storeService.sendMessage(me.id, body.receiverId, body.body);
    // Push to both sender and receiver in real time
    this.messagesGateway.emitNewMessage(message);
    // Send FCM push to receiver
    this.storeService.getDeviceTokens(body.receiverId).then((tokens) => {
      if (tokens.length > 0) {
        void this.fcmService.sendPush(
          tokens,
          me.displayName,
          body.body,
          { senderId: me.id, messageId: message.id },
        );
      }
    }).catch(() => {});
    return message;
  }

  @Get('conversations')
  async getConversations(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<Conversation[]> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getConversations(me.id);
  }

  @Get('conversations/:userId')
  async getThread(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId', new ParseUUIDPipe()) userId: string,
    @Query('limit', new DefaultValuePipe(50), ParseIntPipe) limit: number,
    @Query('before') before?: string,
  ): Promise<{ messages: Message[]; hasMore: boolean }> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const beforeDate = before ? new Date(before) : undefined;
    return this.storeService.getThread(me.id, userId, limit, beforeDate);
  }

  @Patch(':messageId/read')
  @HttpCode(HttpStatus.OK)
  async markRead(
    @Headers('authorization') authorization: string | undefined,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const message = await this.storeService.markMessageRead(messageId, me.id);
    // Socket: instant when sender is connected
    this.messagesGateway.emitReadReceipt(message);
    // FCM: reliable fallback — reaches sender even if socket dropped
    this.storeService.getDeviceTokens(message.senderId).then((tokens) => {
      if (tokens.length > 0 && message.readAt) {
        void this.fcmService.sendReadReceiptPush(tokens, message.id, message.readAt);
      }
    }).catch(() => {});
    return message;
  }
}

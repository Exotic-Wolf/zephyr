import {
  BadRequestException,
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

@Controller('v1/messages')
export class MessagesController {
  constructor(
    private readonly storeService: StoreService,
    private readonly fcmService: FcmService,
  ) {}

  @Post('device-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async registerDeviceToken(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { token: string },
  ): Promise<void> {
    const session =
      await this.storeService.getAuthSessionFromAuthHeader(authorization);
    await this.storeService.upsertDeviceToken(session, body.token);
  }

  @Delete('device-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unregisterDeviceToken(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { token: string },
  ): Promise<void> {
    const session =
      await this.storeService.getAuthSessionFromAuthHeader(authorization);
    await this.storeService.deleteDeviceToken(session, body.token);
  }

  @Post('push')
  @HttpCode(HttpStatus.NO_CONTENT)
  async sendPushNotification(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { recipientId: string; chatId: string; messageId: string },
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    if (!body.recipientId || !body.chatId || !body.messageId) {
      throw new BadRequestException(
        'recipientId, chatId, and messageId are required',
      );
    }
    const tokens = await this.storeService.getDeviceTokens(body.recipientId);
    if (tokens.length > 0) {
      const result = await this.fcmService.sendCommittedChatMessagePush({
        tokens,
        senderId: me.id,
        senderDisplayName: me.displayName,
        recipientId: body.recipientId,
        chatId: body.chatId,
        messageId: body.messageId,
      });
      await this.storeService.deleteDeviceTokensByToken(result.invalidTokens);
      if (!result.sent) {
        throw new BadRequestException(
          'Chat message could not be verified for push',
        );
      }
    }
  }

  @Post()
  async sendMessage(
    @Headers('authorization') authorization: string | undefined,
    @Headers('x-idempotency-key') idempotencyKey: string | undefined,
    @Body() body: SendMessageDto,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const { message, isNew } = await this.storeService.sendMessage(
      me.id,
      body.receiverId,
      body.body,
      idempotencyKey,
    );
    if (isNew) {
      // Send FCM push to receiver
      this.storeService
        .getDeviceTokens(body.receiverId)
        .then((tokens) => {
          if (tokens.length > 0) {
            void this.fcmService
              .sendPush(tokens, me.displayName, body.body, {
                senderId: me.id,
                messageId: message.id,
              })
              .then((result) =>
                this.storeService.deleteDeviceTokensByToken(
                  result.invalidTokens,
                ),
              );
          }
        })
        .catch(() => {});
    }
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
    @Query('after') after?: string,
  ): Promise<{ messages: Message[]; hasMore: boolean }> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const beforeDate = before ? new Date(before) : undefined;
    const afterDate = after ? new Date(after) : undefined;
    return this.storeService.getThread(
      me.id,
      userId,
      limit,
      beforeDate,
      afterDate,
    );
  }

  @Patch(':messageId/delivered')
  @HttpCode(HttpStatus.OK)
  async markDelivered(
    @Headers('authorization') authorization: string | undefined,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const message = await this.storeService.markMessageDelivered(
      messageId,
      me.id,
    );
    return message;
  }

  @Patch(':messageId/read')
  @HttpCode(HttpStatus.OK)
  async markRead(
    @Headers('authorization') authorization: string | undefined,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const message = await this.storeService.markMessageRead(messageId, me.id);
    // FCM: reliable fallback — reaches sender even if socket dropped
    this.storeService
      .getDeviceTokens(message.senderId)
      .then((tokens) => {
        if (tokens.length > 0 && message.readAt) {
          void this.fcmService
            .sendReadReceiptPush(tokens, message.id, message.readAt)
            .then((result) =>
              this.storeService.deleteDeviceTokensByToken(result.invalidTokens),
            );
        }
      })
      .catch(() => {});
    return message;
  }
}

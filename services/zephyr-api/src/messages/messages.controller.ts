import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { StoreService } from '../core/store.service';
import { AgoraChatService } from '../core/agora-chat.service';

@Controller('v1/messages')
export class MessagesController {
  constructor(
    private readonly storeService: StoreService,
    private readonly agoraChatService: AgoraChatService,
  ) {}

  /** Returns an Agora Chat token + credentials for the authenticated user. */
  @Get('chat-token')
  async getChatToken(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<{ appKey: string; chatUserId: string; token: string }> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const chatUserId = this.agoraChatService.toChatUserId(me.id);
    await this.agoraChatService.ensureChatUser(chatUserId);
    const token = this.agoraChatService.buildUserToken(chatUserId);
    return { appKey: this.agoraChatService.appKey, chatUserId, token };
  }

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
}

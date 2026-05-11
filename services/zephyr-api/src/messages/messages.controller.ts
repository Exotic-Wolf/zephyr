import {
  Body,
  Controller,
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
import type { Conversation, Message } from '../core/store.service';
import { SendMessageDto } from './dto/send-message.dto';
import { MessagesGateway } from './messages.gateway';

@Controller('v1/messages')
export class MessagesController {
  constructor(
    private readonly storeService: StoreService,
    private readonly messagesGateway: MessagesGateway,
  ) {}

  @Post()
  async sendMessage(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: SendMessageDto,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const message = await this.storeService.sendMessage(me.id, body.receiverId, body.body);
    // Push to both sender and receiver in real time
    this.messagesGateway.emitNewMessage(message);
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
  ): Promise<Message[]> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getThread(me.id, userId, limit);
  }

  @Patch(':messageId/read')
  @HttpCode(HttpStatus.OK)
  async markRead(
    @Headers('authorization') authorization: string | undefined,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
  ): Promise<Message> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.markMessageRead(messageId, me.id);
  }
}

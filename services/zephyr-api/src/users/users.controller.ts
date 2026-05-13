import { BadRequestException, Body, Controller, Delete, Get, Headers, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { v2 as cloudinary } from 'cloudinary';
import { unlink } from 'fs';
import { StoreService } from '../core/store.service';
import type { UserProfile } from '../core/store.service';
import { UpdateMeDto } from './dto/update-me.dto';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

@Controller('v1/users')
export class UsersController {
  constructor(private readonly storeService: StoreService) {}

  @Get('me')
  async getMe(@Headers('authorization') authorization?: string): Promise<UserProfile> {
    return this.storeService.getUserFromAuthHeader(authorization);
  }

  @Patch('me')
  async updateMe(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: UpdateMeDto,
  ): Promise<UserProfile> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);

    return this.storeService.updateUser(user.id, {
      displayName: body?.displayName,
      avatarUrl: body?.avatarUrl,
      bio: body?.bio,
      gender: body?.gender,
      birthday: body?.birthday,
      countryCode: body?.countryCode,
      language: body?.language,
      callRateCoinsPerMinute: body?.callRateCoinsPerMinute,
      // Only admins may claim a custom public ID
      publicId: user.isAdmin ? body?.publicId : undefined,
    });
  }

  @Post('me/avatar')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async uploadAvatar(
    @Headers('authorization') authorization: string | undefined,
    @UploadedFile() file: Express.Multer.File,
  ): Promise<{ avatarUrl: string }> {
    if (!file) throw new BadRequestException('No file provided');
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    const source = file.buffer
      ? `data:${file.mimetype};base64,${file.buffer.toString('base64')}`
      : file.path;
    if (!source) throw new BadRequestException('File data missing');
    try {
      const result = await cloudinary.uploader.upload(source, {
        folder: 'zephyr/avatars',
        public_id: `user_${user.id}`,
        overwrite: true,
        transformation: [{ width: 400, height: 400, crop: 'fill', gravity: 'face' }],
      });
      await this.storeService.updateUser(user.id, { avatarUrl: result.secure_url });
      return { avatarUrl: result.secure_url };
    } finally {
      if (file.path) unlink(file.path, () => {});
    }
  }

  @Get('me/following')
  async getFollowing(@Headers('authorization') authorization?: string): Promise<string[]> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getFollowing(user.id);
  }

  @Get('search')
  async searchUsers(
    @Query('q') q: string,
  ): Promise<UserProfile[]> {
    return this.storeService.searchUsers(q?.trim() ?? '');
  }

  @Get('by-public-id/:publicId')
  async getUserByPublicId(
    @Param('publicId') publicId: string,
  ): Promise<UserProfile> {
    return this.storeService.getUserByPublicId(publicId);
  }

  @Get(':userId')
  async getUserById(
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<UserProfile> {
    return this.storeService.getUserById(userId);
  }

  @Post(':userId/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  async followUser(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.followUser(me.id, userId);
  }

  @Delete(':userId/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unfollowUser(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.unfollowUser(me.id, userId);
  }
}
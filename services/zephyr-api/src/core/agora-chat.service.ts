import { Injectable, Logger } from '@nestjs/common';
import { ChatTokenBuilder } from 'agora-token';

/**
 * Manages Agora Chat user registration and token generation.
 *
 * Flow:
 * 1. When a Zephyr user needs chat, backend calls `ensureChatUser` to register
 *    them in Agora's system (idempotent — 409 = already exists = fine).
 * 2. Backend generates a user token via `buildUserToken` and returns it to the client.
 * 3. Flutter SDK logs in with (chatUserId, token).
 */
@Injectable()
export class AgoraChatService {
  private readonly logger = new Logger(AgoraChatService.name);

  private get appId(): string {
    return process.env.AGORA_APP_ID?.trim() ?? '';
  }

  private get appCertificate(): string {
    return process.env.AGORA_APP_CERTIFICATE?.trim() ?? '';
  }

  private get orgName(): string {
    return process.env.AGORA_CHAT_ORG_NAME?.trim() ?? '61200027988';
  }

  private get appName(): string {
    return process.env.AGORA_CHAT_APP_NAME?.trim() ?? '200038063';
  }

  get appKey(): string {
    return `${this.orgName}#${this.appName}`;
  }

  private get restHost(): string {
    // Singapore data center
    return process.env.AGORA_CHAT_REST_HOST?.trim() ?? 'a61.chat.agora.io';
  }

  /** Generate a user token for Agora Chat SDK login. */
  buildUserToken(chatUserId: string, expireSeconds = 86400): string {
    return ChatTokenBuilder.buildUserToken(
      this.appId,
      this.appCertificate,
      chatUserId,
      expireSeconds,
    );
  }

  /** Generate an app token for REST API calls. */
  private buildAppToken(expireSeconds = 3600): string {
    return ChatTokenBuilder.buildAppToken(
      this.appId,
      this.appCertificate,
      expireSeconds,
    );
  }

  /**
   * Register a user in Agora Chat. Idempotent — if user already exists (409), succeeds silently.
   * Username must be lowercase alphanumeric + underscore/hyphen/dot, max 64 chars.
   */
  async ensureChatUser(chatUserId: string): Promise<void> {
    const appToken = this.buildAppToken();
    const url = `https://${this.restHost}/${this.orgName}/${this.appName}/users`;

    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${appToken}`,
        },
        body: JSON.stringify({ username: chatUserId }),
      });

      if (res.ok || res.status === 409) {
        // 200 = created, 409 = already exists — both fine
        return;
      }

      const body = await res.text();
      this.logger.warn(`Agora Chat register failed (${res.status}): ${body}`);
    } catch (err) {
      this.logger.error('Agora Chat register error', err);
    }
  }

  /**
   * Convert a Zephyr UUID user ID into a valid Agora Chat username.
   * Agora Chat requires: lowercase, alphanumeric + _-., max 64 chars.
   * We strip hyphens from UUID → 32-char hex string.
   */
  toChatUserId(zephyrUserId: string): string {
    return zephyrUserId.replace(/-/g, '').toLowerCase();
  }
}

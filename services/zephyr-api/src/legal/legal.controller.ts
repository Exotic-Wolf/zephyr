import { Controller, Get, Res } from '@nestjs/common';
import { join } from 'path';

@Controller('legal')
export class LegalController {
  @Get('privacy')
  getPrivacyPolicy(@Res() res: any): void {
    res.sendFile(join(__dirname, 'privacy-policy.html'));
  }

  @Get('terms')
  getTermsOfService(@Res() res: any): void {
    res.sendFile(join(__dirname, 'terms-of-service.html'));
  }
}

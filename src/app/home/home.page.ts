import { Component } from '@angular/core';
import { IonicModule } from '@ionic/angular';
import { CapBrowser, ToolBarType } from 'cap-browser';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
  standalone: true,
  imports: [IonicModule],
})
export class HomePage {
  busy = false;
  constructor() {
    this.init();
  }

  async init() {
    const urlChangeListner = await CapBrowser.addListener('urlChangeEvent', async (info: any) => {
      console.log(info.url);
      if (!info.url.includes('cs-links.netlify')) {
        try {
          if (this.busy) {
            console.error('Multiple attempts to launch links detected');
            return;
          }
          this.busy = true;
          await this.destroy();
          await CapBrowser.close();
          await this.open(info.url);
        } finally {
          this.busy = false;
        }
      }
    });
  }

  async destroy() {
    await CapBrowser.removeAllListeners();
  }

  async close() {
    await CapBrowser.close();
  }

  async open(url: string) {
    CapBrowser.openWebView({
      url,
      title: 'Test',
      shareSubject: 'Share',
      toolbarType: ToolBarType.ACTIVITY,
      shareDisclaimer: { title: 'title', message: 'msg', confirmBtn: 'Confirm', cancelBtn: 'Cancel' },
      isPresentAfterPageLoad: true
    });
  }
}

import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface CardLetterRecord {
  id: number;
  date: string;
  emotion: string;
  ritual: string;
  content: string;
}

interface CardStoredLetterState {
  echoCards: Array<CardLetterRecord>;
}

interface LetterCardData {
  hasLetter: boolean;
  date: string;
  emotionAndRitual: string;
  content: string;
  target: string;
}

export default class EntryFormAbility extends FormExtensionAbility {
  private readonly storeName: string = 'weiyu_letter_store';
  private readonly storeKey: string = 'letters_payload';
  private readonly formIdsKey: string = 'letter_form_ids';

  private getStore(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context, { name: this.storeName });
  }

  private createCardData(): LetterCardData {
    const rawValue: string = this.getStore().getSync(this.storeKey, '') as string;
    if (rawValue.length > 0) {
      try {
        const state: CardStoredLetterState = JSON.parse(rawValue) as CardStoredLetterState;
        const letters: Array<CardLetterRecord> = state.echoCards ?? [];
        if (letters.length > 0) {
          const letter: CardLetterRecord = letters[0];
          const text: string = letter.content.length > 46
            ? `${letter.content.slice(0, 46)}…`
            : letter.content;
          return {
            hasLetter: true,
            date: letter.date,
            emotionAndRitual: `${letter.emotion} · ${letter.ritual}`,
            content: text,
            target: `letter:${letter.id}`
          };
        }
      } catch (_err) {
      }
    }
    return {
      hasLetter: false,
      date: '微语',
      emotionAndRitual: '给此刻留一点空间',
      content: '最近，有没有什么想写下来的？',
      target: 'write'
    };
  }

  private saveFormId(formId: string): void {
    const store: preferences.Preferences = this.getStore();
    const rawIds: string = store.getSync(this.formIdsKey, '[]') as string;
    let ids: Array<string> = [];
    try {
      ids = JSON.parse(rawIds) as Array<string>;
    } catch (_err) {
    }
    if (!ids.includes(formId)) {
      ids.push(formId);
      store.putSync(this.formIdsKey, JSON.stringify(ids));
      store.flush().catch((_err: BusinessError) => {
      });
    }
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = `${want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? ''}`;
    if (formId.length > 0) {
      this.saveFormId(formId);
    }
    return formBindingData.createFormBindingData(this.createCardData());
  }

  onUpdateForm(formId: string): void {
    const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(this.createCardData());
    formProvider.updateForm(formId, data).catch((_err: BusinessError) => {
    });
  }

  onRemoveForm(formId: string): void {
    const store: preferences.Preferences = this.getStore();
    const rawIds: string = store.getSync(this.formIdsKey, '[]') as string;
    let ids: Array<string> = [];
    try {
      ids = JSON.parse(rawIds) as Array<string>;
    } catch (_err) {
    }
    ids = ids.filter((id: string) => id !== formId);
    store.putSync(this.formIdsKey, JSON.stringify(ids));
    store.flush().catch((_err: BusinessError) => {
    });
  }
}

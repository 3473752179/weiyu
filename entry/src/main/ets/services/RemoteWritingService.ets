import { http } from '@kit.NetworkKit';
import { RemoteWritingConfig } from './RemoteWritingConfig';

export interface WritingPromptRequest {
  recipientLabel: string;
  recipientPreset: string;
  emotionLabel: string;
  emotionPreset: string;
  excludePromptIds: Array<string>;
  variationSeed: string;
}

export interface WritingPromptResponse {
  id: string;
  prompt: string;
  matchedBy: string;
  recipientCategory: string;
  emotionCategory: string;
}

export interface AfterglowRequest {
  recipient: string;
  recipientPreset: string;
  emotion: string;
  emotionPreset: string;
  title: string;
  variationSeed: string;
  excludeCandidates: Array<string>;
}

export interface AfterglowResponse {
  requestId: string;
  candidates: Array<string>;
  keywords: Array<string>;
  echo: string;
  engine: string;
}

interface ApiEnvelope<T> {
  success: boolean;
  data?: T;
  message?: string;
}

export class RemoteWritingService {
  private static async postJson<TRequest extends Object, TResponse>(path: string, payload: TRequest): Promise<TResponse> {
    let index: number = 0;
    while (index < RemoteWritingConfig.API_BASE_URLS.length) {
      const client: http.HttpRequest = http.createHttp();
      try {
        const baseUrl: string = RemoteWritingConfig.API_BASE_URLS[index];
        const response: http.HttpResponse = await client.request(`${baseUrl}${path}`, {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          extraData: JSON.stringify(payload),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: RemoteWritingConfig.CONNECT_TIMEOUT_MS,
          readTimeout: RemoteWritingConfig.READ_TIMEOUT_MS
        });
        if (response.responseCode < 200 || response.responseCode >= 300) {
          throw new Error(`HTTP_${response.responseCode}`);
        }
        const raw: string = response.result as string;
        const envelope: ApiEnvelope<TResponse> = JSON.parse(raw) as ApiEnvelope<TResponse>;
        if (!envelope.success || envelope.data === undefined) {
          throw new Error(envelope.message ?? 'REMOTE_DATA_INVALID');
        }
        return envelope.data;
      } catch (_err) {
        index += 1;
      } finally {
        client.destroy();
      }
    }
    throw new Error('REMOTE_SERVICE_UNREACHABLE');
  }

  static matchWritingPrompt(request: WritingPromptRequest): Promise<WritingPromptResponse> {
    return RemoteWritingService.postJson<WritingPromptRequest, WritingPromptResponse>('/api/v1/prompts/match', request);
  }

  static generateAfterglow(request: AfterglowRequest): Promise<AfterglowResponse> {
    return RemoteWritingService.postJson<AfterglowRequest, AfterglowResponse>('/api/v1/afterglow', request);
  }
}

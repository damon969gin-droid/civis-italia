/**
 * Tipi e costanti condivise tra mobile (Flutter via generato) e backend.
 * Per ora TypeScript puro. In futuro si potrà generare anche Dart.
 */

export type DocumentPriority = 'high' | 'medium' | 'low';

export type DocumentStatus =
  | 'uploading'
  | 'processing'
  | 'ready'
  | 'error'
  | 'archived';

export interface Deadline {
  label: string;
  date: string; // ISO 8601
  type?: string; // es. 'ISEE', '730', 'IMU'
}

export interface Amount {
  label: string;
  value: number;
  currency: string; // 'EUR'
}

export interface Contact {
  name: string;
  phone?: string;
  email?: string;
  url?: string;
}

export interface DocumentAnalysis {
  summary: string;
  meaning: string;
  actions: string[];
  deadlines: Deadline[];
  amounts: Amount[];
  contacts: Contact[];
  requiredDocuments: string[];
  priority: DocumentPriority;
  estimatedTimeMinutes: number;
  rawOcrText?: string;
}

export interface UserPlan {
  type: 'free' | 'premium' | 'family' | 'professional';
  documentsLimitPerMonth: number | null; // null = illimitato
}

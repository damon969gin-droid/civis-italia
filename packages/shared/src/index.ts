// Tipi e costanti condivise tra mobile e backend
export type DocumentPriority = 'high' | 'medium' | 'low';

export interface DocumentAnalysis {
  summary: string;
  meaning: string;
  actions: string[];
  deadlines: { label: string; date: string }[];
  amounts: { label: string; value: number; currency: string }[];
  contacts: { name: string; phone?: string; url?: string }[];
  requiredDocuments: string[];
  priority: DocumentPriority;
  estimatedTimeMinutes: number;
}

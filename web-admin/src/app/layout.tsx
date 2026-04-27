import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Caisse Facile — Back-office',
  description: 'Tableau de bord épicier',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body className="bg-slate-50 min-h-screen text-slate-900">
        <header className="bg-emerald-700 text-white px-6 py-4 shadow">
          <h1 className="text-xl font-bold">Caisse Facile — Back-office</h1>
        </header>
        <main className="max-w-6xl mx-auto p-6">{children}</main>
      </body>
    </html>
  );
}

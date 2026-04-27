'use client';

import { useState } from 'react';
import { browserClient } from '@/lib/supabase-browser';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setLoading(true);
    const sb = browserClient();
    const { error } = await sb.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) {
      setErr(error.message);
      return;
    }
    router.replace('/');
  }

  return (
    <div className="max-w-md mx-auto bg-white rounded-xl shadow p-8 mt-16">
      <h2 className="text-2xl font-bold mb-6">Connexion</h2>
      <form onSubmit={submit} className="space-y-4">
        <input
          className="w-full border rounded p-3"
          placeholder="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          className="w-full border rounded p-3"
          placeholder="Mot de passe"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        {err && <p className="text-red-600 text-sm">{err}</p>}
        <button
          disabled={loading}
          className="w-full bg-emerald-700 text-white rounded py-3 font-semibold disabled:opacity-50"
        >
          {loading ? '…' : 'Se connecter'}
        </button>
      </form>
    </div>
  );
}

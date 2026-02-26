'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { MockAgentEscrowClient, MOCK_MODE } from '@/lib/mockSdk';

export function CreateTaskForm() {
  const { address } = useAccount();
  
  const [formData, setFormData] = useState({
    provider: '',
    description: '',
    amount: '',
    deadline: '24',
  });

  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    setLoading(true);
    setTxHash(null);

    try {
      const mockEscrow = new MockAgentEscrowClient();
      
      const { hash, intentId } = await mockEscrow.createIntent(
        {
          provider: formData.provider,
          amount: parseUnits(formData.amount, 6),
        },
        {
          description: formData.description,
          deliverables: ['result.json'],
        }
      );

      setTxHash(hash);
      alert(`Task created!\nIntent ID: ${intentId.substring(0, 15)}...`);

      setFormData({
        provider: '',
        description: '',
        amount: '',
        deadline: '24',
      });
    } catch (error) {
      console.error('Error:', error);
      alert('Error: ' + (error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-gray-900">
          Create New Task
        </h2>
        <span className="px-2 py-1 bg-yellow-100 text-yellow-800 text-xs font-medium rounded">
          DEMO MODE
        </span>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            AI Agent Address
          </label>
          <input
            type="text"
            value={formData.provider}
            onChange={(e) => setFormData({ ...formData, provider: e.target.value })}
            placeholder="0x..."
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Task Description
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            placeholder="Describe the task for the AI agent..."
            rows={4}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Payment (USDC)
          </label>
          <input
            type="number"
            step="0.01"
            value={formData.amount}
            onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
            placeholder="100.00"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Deadline (hours)
          </label>
          <select
            value={formData.deadline}
            onChange={(e) => setFormData({ ...formData, deadline: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="24">24 hours</option>
            <option value="48">48 hours</option>
            <option value="72">72 hours</option>
            <option value="168">1 week</option>
          </select>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 text-white py-3 px-4 rounded-md font-medium hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
        >
          {loading ? 'Creating Task...' : 'Create Task'}
        </button>

        {txHash && (
          <div className="mt-4 p-3 bg-green-50 border border-green-200 rounded-md">
            <p className="text-sm text-green-800">
              ✅ Task created!
            </p>
            <p className="text-xs text-gray-600 font-mono mt-1">
              {txHash}
            </p>
          </div>
        )}
      </form>
    </div>
  );
}

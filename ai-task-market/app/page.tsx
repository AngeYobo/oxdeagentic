'use client';

import { useEffect, useState } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';
import { CreateTaskForm } from '@/components/CreateTaskForm';
import { TaskList } from '@/components/TaskList';

export default function Home() {
  const { isConnected } = useAccount();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <main className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                🤖 AI Task Market
              </h1>
              <p className="text-sm text-gray-500">
                Powered by DeAgentic Protocol
              </p>
            </div>
            {mounted ? <ConnectButton /> : <div className="h-10 w-36" />}
          </div>
        </div>
      </header>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {!mounted || !isConnected ? (
          <div className="text-center py-20">
            <h2 className="text-3xl font-bold text-gray-900 mb-4">
              Welcome to AI Task Market
            </h2>
            <p className="text-xl text-gray-600 mb-8">
              Connect your wallet to create tasks for AI agents
            </p>
            <div className="flex justify-center">
              {mounted ? <ConnectButton /> : <div className="h-10 w-36" />}
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            {/* Create Task Form */}
            <div className="lg:col-span-1">
              <CreateTaskForm />
            </div>

            {/* Task List */}
            <div className="lg:col-span-2">
              <TaskList />
            </div>
          </div>
        )}
      </div>
    </main>
  );
}

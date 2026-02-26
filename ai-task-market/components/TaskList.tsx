'use client';

import { useState, useEffect } from 'react';
import { useAccount, usePublicClient } from 'wagmi';
import { AgentEscrowClient, getAddresses } from '@deagentic/sdk';
import { formatUnits, parseAbiItem, type Address, type Hash } from 'viem';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const ENV_ESCROW_ADDRESS = (() => {
  const envAddress = process.env.NEXT_PUBLIC_ESCROW_ADDRESS;
  return envAddress ? (envAddress as Address) : null;
})();

interface Task {
  id: string;
  provider: string;
  amount: string;
  state: number;
  deadline: string;
}

export function TaskList() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadTasks();
  }, [address, publicClient]);

  const loadTasks = async () => {
    if (!publicClient || !address) {
      setTasks([]);
      setLoading(false);
      return;
    }

    try {
      const chainId = publicClient.chain?.id;
      const escrowAddress = ENV_ESCROW_ADDRESS
        ?? (chainId ? (() => {
          try {
            return getAddresses(chainId).agentEscrow;
          } catch {
            return ZERO_ADDRESS as Address;
          }
        })() : (ZERO_ADDRESS as Address));

      if (escrowAddress.toLowerCase() === ZERO_ADDRESS) {
        setTasks([]);
        return;
      }

      const latestBlock = await publicClient.getBlockNumber();
      const maxRange = 9_000n;
      const fromBlock = latestBlock > maxRange ? latestBlock - maxRange : 0n;
      const event = parseAbiItem('event IntentCreated(bytes32 indexed intentId, address indexed payer, bytes32 commitHash, uint64 timestamp)');
      const createdLogs = [];

      let cursor = fromBlock;
      while (cursor <= latestBlock) {
        const chunkTo = cursor + maxRange < latestBlock ? cursor + maxRange : latestBlock;
        const chunk = await publicClient.getLogs({
          address: escrowAddress,
          event,
          args: { payer: address },
          fromBlock: cursor,
          toBlock: chunkTo,
        });
        createdLogs.push(...chunk);
        cursor = chunkTo + 1n;
      }

      const intentIds = [...new Set(
        createdLogs
          .map((log) => log.args.intentId)
          .filter((intentId): intentId is Hash => Boolean(intentId))
      )];

      if (intentIds.length === 0) {
        setTasks([]);
        return;
      }

      const escrowClient = new AgentEscrowClient(escrowAddress, publicClient);
      const intents = await Promise.all(
        intentIds.map(async (intentId) => {
          try {
            const intent = await escrowClient.getIntent(intentId);
            return {
              id: intentId,
              provider: intent.provider,
              amount: formatUnits(intent.amount, 6),
              state: Number(intent.state),
              deadline: intent.revealDeadline.toString(),
            };
          } catch {
            return null;
          }
        })
      );

      setTasks(intents.flatMap((intent) => (intent ? [intent] : [])));
    } catch (error) {
      console.error('Error loading tasks:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStateLabel = (state: number) => {
    const states = ['None', 'Created', 'Revealed', 'Disputed', 'Settled (Provider)', 'Settled (Payer)', 'Split', 'No Reveal'];
    return states[state] || 'Unknown';
  };

  const getStateColor = (state: number) => {
    const colors = {
      1: 'bg-yellow-100 text-yellow-800',
      2: 'bg-blue-100 text-blue-800',
      3: 'bg-red-100 text-red-800',
      4: 'bg-green-100 text-green-800',
      7: 'bg-gray-100 text-gray-800',
    };
    return colors[state as keyof typeof colors] || 'bg-gray-100 text-gray-800';
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-4 bg-gray-200 rounded w-3/4"></div>
          <div className="h-4 bg-gray-200 rounded"></div>
          <div className="h-4 bg-gray-200 rounded w-5/6"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <h2 className="text-xl font-bold text-gray-900 mb-6">
        Your Tasks
      </h2>

      {tasks.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500">No tasks yet. Create your first task!</p>
        </div>
      ) : (
        <div className="space-y-4">
          {tasks.map((task) => (
            <div
              key={task.id}
              className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow"
            >
              <div className="flex justify-between items-start mb-3">
                <div>
                  <p className="font-medium text-gray-900">Task {task.id}</p>
                  <p className="text-sm text-gray-500">
                    Agent: {task.provider}
                  </p>
                </div>
                <span
                  className={`px-3 py-1 rounded-full text-xs font-medium ${getStateColor(task.state)}`}
                >
                  {getStateLabel(task.state)}
                </span>
              </div>

              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-gray-500">Amount</p>
                  <p className="font-medium text-gray-900">{task.amount} USDC</p>
                </div>
                <div>
                  <p className="text-gray-500">Deadline</p>
                  <p className="font-medium text-gray-900">{task.deadline}</p>
                </div>
              </div>

              <div className="mt-4 flex gap-2">
                <button className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 text-sm font-medium transition-colors">
                  View Details
                </button>
                {task.state === 1 && (
                  <button className="flex-1 px-4 py-2 bg-red-100 text-red-700 rounded-md hover:bg-red-200 text-sm font-medium transition-colors">
                    Cancel
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

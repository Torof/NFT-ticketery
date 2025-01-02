'use client'

import { useAccount, useConnect, useDisconnect } from 'wagmi'

export default function Home() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div>
        {isConnected ? (
          <>
            <div>Connected to {address}</div>
            <button 
              onClick={() => disconnect()}
              className="px-4 py-2 bg-red-500 text-white rounded-lg mt-2"
            >
              Disconnect
            </button>
          </>
        ) : (
          <button 
            onClick={() => connect({ connector: connectors[0] })}
            className="px-4 py-2 bg-blue-500 text-white rounded-lg"
          >
            Connect Wallet
          </button>
        )}
      </div>
    </main>
  )
}
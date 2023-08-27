import Link from "next/link";
import React, { useEffect, useState } from "react";
import { useWeb3Modal } from "@web3modal/react";
import { useAccount, useConnect, useEnsName } from "wagmi";

const Header: React.FC = () => {
  const { open, close } = useWeb3Modal();
  const { address, isConnected } = useAccount();
  const [connectState, setConnectState] = useState(false);
  const { data: ensName } = useEnsName({ address });

  useEffect(() => {
    if (isConnected) {
      setConnectState(true);
    } else {
      setConnectState(false);
    }
  }, [address]);

  const shortenAddress = (address: string | undefined | null) => {
    const maxLength = 10;
    if (address != undefined) {
      const start = address.substring(0, maxLength / 2);
      const end = address.substring(address.length - maxLength / 2);
      address = `${start}...${end}`;
      return address;
    }
  };

  return (
    <div className="flex py-10 px-20 justify-between items-center fixed top-0 left-0 container">
      <div className="flex justify-center items-center space-x-2 h-full">
        <Link href="/" className="text-3xl font-medium">
          TCProtocol
        </Link>
        <span className="bg-gray-100 text-gray-800 text-xs font-medium mr-2 px-2.5 rounded flex items-center">
          Sepolia Testnet
        </span>
      </div>

      <nav>
        <ul className="flex items-center justify-center space-x-5">
          <li className="hover:underline transition-all">
            <Link href={"/"}>Home</Link>
          </li>
          <li className="hover:underline transition-all">
            <Link href={"/dashboard"}>Dashboard</Link>
          </li>
          <li className="hover:underline transition-all">
            <Link href={"/borrow"}>Borrow</Link>
          </li>
          <li className="hover:underline transition-all">
            <Link href={"/faucet"}>Faucet</Link>
          </li>
          <li className="hover:underline transition-all">
            <a
              target="_blank"
              href={
                "https://github.com/terrancrypt/web3hackfest/tree/master#about"
              }
            >
              Docs
            </a>
          </li>
        </ul>
      </nav>

      <div className="whitespace-nowrap">
        {connectState == true ? (
          <button
            className="w-full overflow-hidden text-ellipsis bg-white bg-opacity-10 text-white p-2 rounded-lg hover:scale-95 transition-al"
            onClick={() => open()}
          >
            {shortenAddress(address ?? ensName)}
          </button>
        ) : (
          <button
            className="bg-white bg-opacity-10 text-white p-2 rounded-lg hover:scale-95 transition-all"
            onClick={() => open()}
          >
            Connect Wallet
          </button>
        )}
      </div>
    </div>
  );
};

export default Header;

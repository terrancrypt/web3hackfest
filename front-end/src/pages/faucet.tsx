import React, { useState, useEffect } from "react";
import { writeContract, fetchBalance, getAccount } from "@wagmi/core";
import MockTokenABI from "../abis/MockTokenABI.json";
import { message } from "antd";
import Head from "next/head";

interface DataAssets {
  img: string;
  name: string;
  symbol: string;
  address: string;
  contractAbi: any;
}

const dataAssets: DataAssets[] = [
  {
    img: "https://assets.coingecko.com/coins/images/2518/small/weth.png?1628852295",
    name: "Wrapped ETH",
    symbol: "WETH",
    address: "61facfdcd0804ca6847e7d7a5a0c2e00307a84cd",
    contractAbi: MockTokenABI,
  },
  {
    img: "https://assets.coingecko.com/coins/images/7598/small/wrapped_bitcoin_wbtc.png?1548822744",
    name: "Wrapped BTC",
    symbol: "WBTC",
    address: "069F34476ba3f540f4979303904957294caAae47",
    contractAbi: MockTokenABI,
  },
];

const Faucet = () => {
  const [tokenBalances, setTokenBalances] = useState<{
    [address: string]: string;
  }>({});

  const addressInfo = getAccount();

  const getFaucet = async (address: string, contractAbi: any) => {
    try {
      const { hash } = await writeContract({
        address: `0x${address}`,
        abi: contractAbi,
        functionName: "faucet",
        args: [],
      });
      message.success(`Faucet success! Transaction Hash: ${hash}`);
    } catch (error: any) {
      message.error(error.message);
    }
  };

  useEffect(() => {
    const fetchTokenBalances = async () => {
      const balances: { [address: string]: string } = {};
      for (const item of dataAssets) {
        try {
          const balance = await fetchBalance({
            address: addressInfo.address as any,
            token: `0x${item.address}`,
          });
          balances[item.address] = Number(balance.formatted).toFixed(2);
        } catch (error) {
          console.error(
            `Error fetching balance for token ${item.name}:`,
            error
          );
        }
      }
      setTokenBalances(balances);
    };

    fetchTokenBalances();
  }, []);

  return (
    <>
      <Head>
        <title>Faucet</title>
      </Head>
      <section className="text-center space-y-6">
        <div className="space-y-4">
          <h1 className="text-3xl font-bold">FAUCET</h1>
          <p>
            With testnet Faucet you can get free assets to test the TC Protocol.
            Make sure to switch your wallet provider to the SEPOLIA testnet
            network, select desired asset, and click ‘Faucet’ to get tokens
            transferred to your wallet.
          </p>
          <p>
            You need Sepolia ETH to pay transaction fees in the protocol. Pick
            up at{" "}
            <a
              href="https://sepoliafaucet.com/"
              target="_blank"
              className="underline"
            >
              Sepolia Faucet
            </a>
            .
          </p>
        </div>
        <div className="text-left bg-white bg-opacity-10 rounded-lg p-2">
          <h1 className="text-2xl font-semibold ml-2">Test Assets</h1>
          <div className="mt-2">
            <ul>
              {dataAssets.map((item, index) => (
                <li
                  key={index}
                  className="border-b-2 py-4 px-2 flex justify-between items-center"
                >
                  <div className="flex items-center justify-start space-x-2">
                    <img src={item.img} className="w-10 h-10" />
                    <div className="w-32">
                      <h2>{item.name}</h2>
                      <span className="text-sm">{item.symbol}</span>
                    </div>
                    <div className="flex flex-col justify-center items-center gap-2 pl-4">
                      <button className="p-2 bg-black rounded-lg text-xs hover:scale-90">
                        <a
                          href={`https://sepolia.etherscan.io/address/0x${item.address}`}
                          target="_blank"
                        >
                          Etherscan
                        </a>
                      </button>
                    </div>
                  </div>
                  <div>
                    <p>
                      Balance: {tokenBalances[item.address] || "Loading..."}{" "}
                      {item.symbol}
                    </p>
                  </div>
                  <div>
                    <button
                      className="p-2 bg-black rounded-lg hover:scale-90"
                      onClick={() => getFaucet(item.address, item.contractAbi)}
                    >
                      Faucet
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>
    </>
  );
};

export default Faucet;

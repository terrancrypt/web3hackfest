import { Table, message } from "antd";
import { ColumnsType } from "antd/es/table";
import Head from "next/head";
import React, { useEffect, useState } from "react";
import { getAccount } from "@wagmi/core";
import {
  getCurrentVaultId,
  getUSDValueOfCollateral,
  getVaultAddress,
  getVaultBalance,
} from "@/contract-functions/interactEngineContract";
import {
  getTokenBalanceOf,
  getTokenName,
  getTokenSymbol,
} from "@/contract-functions/interactTokenContract";
import Link from "next/link";
import { BigNumberish, formatEther } from "ethers";

interface Vault {
  key: React.Key;
  vaultId: number;
  vaultAddress: string | null;
  vaultBalance: string;
  vaultValue: string;
  accountBalance: string;
  tokenName: string | null;
  tokenSymbol: string | null;
}

const columns: ColumnsType<Vault> = [
  { title: "Collateral/Debt", dataIndex: "tokenName", key: "tokenName" },
  {
    title: "Total Deposited",
    dataIndex: "vaultBalance",
    key: "vaultBalance",
  },
  {
    title: "Total Value In USD",
    dataIndex: "vaultValue",
    key: "vaultValue",
  },
  {
    title: "Your Balance",
    dataIndex: "accountBalance",
    key: "accountBalance",
  },

  {
    title: "",
    dataIndex: "vaultId",
    key: "vaultId",
    render: (text) => (
      <Link
        href={`/borrow/${text}`}
        className="p-3 bg-black rounded-lg text-white hover:text-white hover:scale-110"
      >
        Borrow
      </Link>
    ),
    width: 30,
  },
];

const Borrow = () => {
  const [vaultData, setVaultData] = useState<Vault[]>();
  const [loading, setLoading] = useState(false);
  const account = getAccount();

  const fetchData = async () => {
    setLoading(true);
    const vaultData: Vault[] = [];
    const currentVaultId: number = await getCurrentVaultId();
    let accountBalance: bigint | null;
    try {
      for (let i = 0; i < currentVaultId; i++) {
        const vaultAddress: string | null = await getVaultAddress(i);
        const vaultBalance: bigint = await getVaultBalance(i);
        const vaultValue = await getUSDValueOfCollateral(
          vaultAddress,
          Number(vaultBalance)
        );
        const tokenName: string | null = await getTokenName(vaultAddress);
        const tokenSymbol: string | null = await getTokenSymbol(vaultAddress);
        accountBalance = await getTokenBalanceOf(account.address, vaultAddress);

        vaultData.push({
          key: i + 1,
          vaultId: i,
          vaultAddress,
          vaultBalance:
            Number(formatEther(vaultBalance as BigNumberish)).toFixed(2) +
            ` ${tokenSymbol}`,
          vaultValue:
            `$ ` +
            Number(formatEther(vaultValue as BigNumberish)).toLocaleString(),
          accountBalance:
            Number(formatEther(accountBalance as BigNumberish)).toFixed(2) +
            ` ${tokenSymbol}`,
          tokenName: `${tokenSymbol}/tcUSD`,
          tokenSymbol,
        });
      }
      setVaultData(vaultData);
    } catch (error) {
      message.error("Failed to fetch data!");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <>
      <Head>
        <title>Borrow</title>
      </Head>
      <section className="text-center space-y-6">
        <h1 className="text-3xl font-bold">BORROW</h1>
        <div className="rounded-xl bg-white bg-opacity-20 p-4">
          <Table
            columns={columns}
            dataSource={vaultData}
            pagination={false}
            loading={loading}
          />
        </div>
      </section>
    </>
  );
};

export default Borrow;

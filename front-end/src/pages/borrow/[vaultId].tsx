import {
  getTcUSDAmountCanBorrow,
  getUSDValueOfCollateral,
  getUserVaultBalance,
  getVaultAddress,
} from "@/contract-functions/interactEngineContract";
import {
  getTokenBalanceOf,
  getTokenName,
  getTokenSymbol,
} from "@/contract-functions/interactTokenContract";
import Head from "next/head";
import { useRouter } from "next/router";
import React, { Fragment, useEffect, useState } from "react";
import { getAccount } from "@wagmi/core";
import { Skeleton, message } from "antd";
import BorrowSteps from "@/components/borrow-steps/BorrowSteps";

interface Vault {
  collateral: string | null;
  price: number;
  tokenName: string | null;
  tokenSymbol: string | null;
  accountBalance: string | null;
  accountDeposited: number | null;
  accountTcUSDCanBorrow: number | null;
}

const BorrowPage = () => {
  const {
    query: { vaultId },
  } = useRouter();
  const account = getAccount();
  const [vault, setVault] = useState<Vault>();
  const [loading, setLoading] = useState(false);

  const fetchData = async () => {
    try {
      setLoading(true);
      let accountBalance: string | null;
      let accountDeposited: number | null;
      let accountTcUSDCanBorrow: number | null;
      if (vaultId) {
        const collateral = await getVaultAddress(Number(vaultId));
        const price = await getUSDValueOfCollateral(collateral, 1);
        const tokenName = await getTokenName(collateral);
        const tokenSymbol = await getTokenSymbol(collateral);

        if (account.connector != undefined) {
          accountBalance = await getTokenBalanceOf(
            account.address,
            vault?.collateral
          );
          accountDeposited = await getUserVaultBalance(
            Number(vaultId),
            account.address as string
          );
          accountTcUSDCanBorrow = await getTcUSDAmountCanBorrow(
            Number(vaultId),
            account.address as string
          );
        } else {
          accountBalance = null;
          accountDeposited = null;
          accountTcUSDCanBorrow = null;
        }

        setVault({
          collateral,
          price,
          tokenName,
          tokenSymbol,
          accountBalance,
          accountDeposited,
          accountTcUSDCanBorrow,
        });
      }
    } catch (error) {
      message.error("Failed to fetch data!");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [vaultId, account.status]);

  const renderVaultInfor = () => {
    if (loading === true) {
      return (
        <div>
          <Skeleton />
        </div>
      );
    }
    return (
      <Fragment>
        <div className="flex space-x-3">
          <h1 className="font-bold text-3xl">{vault?.tokenName} </h1>
          <span className="text-sm">Vault</span>
        </div>
        <p className="mt-3">Current Price: ${vault?.price}</p>
        <p className="mt-3">Min Collateral Rate: 200%</p>
        {account.connector != undefined ? (
          <div className="border-t mt-4 pt-3">
            <h2 className="font-bold text-lg">Your information</h2>
            <p className="mt-3">
              Wallet balance: {vault?.accountBalance} {vault?.tokenSymbol}
            </p>
            <p className="mt-3">
              Total Deposited: {vault?.accountDeposited} {vault?.tokenSymbol}
            </p>
            <p className="mt-3">
              Avaiable tcUSD to borrow: {vault?.accountTcUSDCanBorrow}
            </p>
          </div>
        ) : (
          <></>
        )}
      </Fragment>
    );
  };

  return (
    <>
      <Head>
        <title>Borrow</title>
      </Head>
      <section className="flex gap-6">
        <div className="bg-white bg-opacity-20 rounded-xl p-4 w-[300px] h-[400px]">
          {renderVaultInfor()}
        </div>
        <div className="flex-grow bg-white bg-opacity-20 rounded-xl p-4">
          <BorrowSteps />
        </div>
      </section>
    </>
  );
};

export default BorrowPage;

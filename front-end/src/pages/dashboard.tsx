import { Table, message } from "antd";
import { ColumnsType } from "antd/es/table";
import Head from "next/head";
import Link from "next/link";
import React, { useState, useEffect } from "react";
import { getAccount, waitForTransaction } from "@wagmi/core";
import {
  canclePosition,
  getAllPostionExists,
  getUniquePosition,
  getVaultAddress,
} from "@/contract-functions/interactEngineContract";
import { formatEther } from "ethers";
import { getTokenSymbol } from "@/contract-functions/interactTokenContract";

interface Position {
  key: React.Key;
  positionId: number;
  vaultId: number;
  collateralSymbol: string | null;
  amountCollateral: string;
  amountToBorrow: string;
  healthFactor: string;
}

const Dashboard = () => {
  const [positionData, setPositionData] = useState<Position[]>();
  const [loading, setLoading] = useState(false);
  const [cancellationSuccess, setCancellationSuccess] = useState(false);
  const account = getAccount();

  const columns: ColumnsType<Position> = [
    {
      title: "Collateral/Debt",
      dataIndex: "collateralSymbol",
      key: "collateralSymbol",
    },
    {
      title: "Amount Collateral",
      dataIndex: "amountCollateral",
      key: "amountCollateral",
    },
    {
      title: "Amount tcUSD Borrowed",
      dataIndex: "amountToBorrow",
      key: "amountToBorrow",
    },
    {
      title: "Health Factor",
      dataIndex: "healthFactor",
      key: "healthFactor",
    },

    {
      title: "",
      dataIndex: "positionId",
      key: "positionId",
      render: (text: any) => (
        <button
          onClick={() => cancelPosition(Number(text))}
          className="p-3 bg-black rounded-lg text-white hover:text-white hover:scale-110"
        >
          Cancel
        </button>
      ),
      width: 30,
    },
  ];

  const fetchData = async () => {
    setLoading(true);
    let positionResult: Position[] = [];
    let positionCount: number[] | null;
    try {
      positionCount = await getAllPostionExists(account.address as any);
      if (positionCount) {
        await Promise.all(
          positionCount.map(async (positionId: number) => {
            const dataBlock = await getUniquePosition(
              positionId,
              account.address as any
            );
            const address = await getVaultAddress(Number(dataBlock[0]));
            const symbol = await getTokenSymbol(address);
            positionResult.push({
              key: Number(formatEther(dataBlock[2])),
              positionId,
              vaultId: Number(dataBlock[0]),
              collateralSymbol: symbol ? symbol : null,
              amountCollateral: Number(formatEther(dataBlock[2])).toFixed(2),
              amountToBorrow: Number(formatEther(dataBlock[3])).toFixed(2),
              healthFactor: Number(formatEther(dataBlock[4])).toFixed(2),
            });
          })
        );
        setPositionData(positionResult);
      }
    } catch (error) {
      message.error("Failed to fetch data!");
    } finally {
      setLoading(false);
    }
  };

  const cancelPosition = async (positionId: number) => {
    setLoading(true);
    try {
      const hash = await canclePosition(positionId, account.address as any);
      if (hash == null) {
        throw message.error("Transaction Error");
      } else {
        const wait: any = await waitForTransaction({
          confirmations: 1,
          hash: hash as any,
        });
        if (wait.status == "success") {
          message.success("Cancle position success!");
          setLoading(false);
          setCancellationSuccess(true);
        } else {
          throw message.error("Transaction failed");
        }
      }
    } catch (error) {
      message.error("Failed to fetch data!");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [cancellationSuccess]);

  return (
    <>
      <Head>
        <title>Dashboard</title>
      </Head>
      <section className="text-center space-y-6">
        <h1 className="text-3xl font-bold">DASHBOARD</h1>
        <div className="rounded-xl bg-white bg-opacity-20 p-4">
          <h2 className="pb-4">Your Open Postions</h2>
          <Table
            columns={columns}
            dataSource={positionData}
            pagination={false}
            loading={loading}
          />
        </div>
      </section>
    </>
  );
};

export default Dashboard;

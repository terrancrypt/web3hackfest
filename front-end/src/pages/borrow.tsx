import { Table } from "antd";
import { ColumnsType } from "antd/es/table";
import React from "react";

const AboutPage = () => {
  interface DataType {
    key: React.Key;
    collateral: string;
    totalDeposited: number;
    borrowRate: string;
  }

  const columns: ColumnsType<DataType> = [
    { title: "Collateral", dataIndex: "collateral", key: "collateral" },
    {
      title: "Total Deposited",
      dataIndex: "totalDeposited",
      key: "totalDeposited",
    },
    { title: "Borrow Rate", dataIndex: "borrowRate", key: "borrowRate" },
    {
      title: "",
      dataIndex: "",
      key: "x",
      render: () => (
        <a className="p-3 bg-black rounded-lg text-white hover:text-white hover:scale-110">
          Borrow
        </a>
      ),
    },
  ];

  const data: DataType[] = [
    {
      key: 1,
      collateral: "WETH/tcUSD",
      totalDeposited: 32,
      borrowRate: "0%",
    },
  ];

  return (
    <section className="text-center space-y-6">
      <h1 className="text-3xl font-bold">BORROW</h1>
      <div className="rounded-xl bg-white bg-opacity-20 p-4">
        <Table columns={columns} dataSource={data} pagination={false} />
      </div>
    </section>
  );
};

export default AboutPage;

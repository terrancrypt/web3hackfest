import {
  engineContract,
  getVaultAddress,
} from "@/contract-functions/interactEngineContract";
import { Form, InputNumber, Slider, Spin, message } from "antd";
import { useRouter } from "next/router";
import React, { useState, useEffect } from "react";
import { getAccount, waitForTransaction } from "@wagmi/core";
import {
  getTokenBalanceOf,
  tokenApprove,
} from "@/contract-functions/interactTokenContract";

interface Step2Props {
  current: number;
  setCurrent: (value: number) => void;
}

const Step2: React.FC<Step2Props> = ({ current, setCurrent }) => {
  const {
    query: { vaultId },
  } = useRouter();
  const account = getAccount();
  const [inputValue, setInputValue] = useState(1);
  const [collateral, setCollateral] = useState("");
  const [accountBalance, setAccountBalance] = useState(0);
  const [txLoading, setTxLoading] = useState(false);

  const onChange = (value: any) => {
    if (isNaN(value)) {
      return;
    }
    setInputValue(value);
  };

  const fetchData = async () => {
    try {
      const collateral = await getVaultAddress(Number(vaultId));
      let accountBalance: string | null;
      if (account.connector != undefined) {
        accountBalance = await getTokenBalanceOf(account.address, collateral);
        setAccountBalance(Number(accountBalance));
      }
      if (collateral != null) {
        setCollateral(collateral);
      }
    } catch {
      message.error("Cannot fetch data!");
    }
  };

  const onFinish = (values: any) => {
    if (values.slider != null) {
    }
  };

  const depositCollateral = () => {
    try {
      setTxLoading(true);
    } catch (error) {
      message.error("Transaction failed");
    } finally {
      setTxLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [account.status]);
  return (
    <div className="px-32 py-16">
      {!txLoading ? (
        <Form onFinish={onFinish}>
          <span className="text-white font-semibold text-lg pb-2">
            Amount you want to deposit
          </span>
          <Form.Item name="slider" style={{ marginBottom: "0" }}>
            <Slider
              min={1}
              max={accountBalance}
              onChange={onChange}
              value={typeof inputValue === "number" ? inputValue : 0}
            />
          </Form.Item>

          <Form.Item name="slider">
            <InputNumber
              min={1}
              max={accountBalance}
              style={{ margin: "0 16px" }}
              value={inputValue}
              onChange={onChange}
            />
          </Form.Item>
          <Form.Item>
            <button
              type="submit"
              className="p-4 rounded-xl bg-black text-white hover:scale-90 transition-all"
            >
              Deposit
            </button>
          </Form.Item>
        </Form>
      ) : (
        <>
          <Spin
            size="large"
            tip="Transaction in progress..."
            spinning={txLoading}
          >
            <div className="content" />
          </Spin>
        </>
      )}
    </div>
  );
};

export default Step2;

import { Button, Steps, message } from "antd";
import React, { useState } from "react";
import Step1 from "./Step1";
import Step2 from "./Step2";

const BorrowSteps = () => {
  const [current, setCurrent] = useState(0);
  const steps = [
    {
      title: "Deposit Collateral",
      content: <Step1 current={current} setCurrent={setCurrent} />,
    },
    {
      title: "Create Position",
      content: <Step2 current={current} setCurrent={setCurrent} />,
    },
  ];

  const items = steps.map((item) => ({
    key: item.title,
    title: item.title,
  }));

  const contentStyle: React.CSSProperties = {
    lineHeight: "260px",
    textAlign: "center",
    marginTop: 16,
  };

  return (
    <div>
      <Steps current={current} items={items} />
      <div style={contentStyle}>{steps[current].content}</div>
      <div style={{ marginTop: 24 }}></div>
    </div>
  );
};

export default BorrowSteps;

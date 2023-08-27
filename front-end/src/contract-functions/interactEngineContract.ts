import { writeContract, readContract } from "@wagmi/core";
import EngineABI from "../abis/EngineABI.json";
import { parseEther } from "ethers";

const engineContract = {
  address: "0x11946A8ab0FC26d3975519Fd031D1440E6088B58",
  abi: EngineABI,
};

const getCurrentVaultId = async (): Promise<number> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getCurrentVaultId",
  });
  return Number(data);
};

const getVaultAddress = async (vaultId: number): Promise<string | null> => {
  try {
    const data: any = await readContract({
      ...(engineContract as any),
      functionName: "getVaultAddress",
      args: [vaultId],
    });
    return data;
  } catch (error) {
    console.log("getVaultAddress Error!", error);
    return null;
  }
};

const getVaultBalance = async (vaultId: number): Promise<bigint> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getVaultBalance",
    args: [vaultId],
  });
  return data;
};

const getUSDValueOfCollateral = async (
  collateral: string | null,
  amount: number
): Promise<bigint> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getUSDValueOfCollateral",
    args: [collateral, amount],
  });
  return data;
};

const getUserVaultBalance = async (
  vauldId: number,
  userAddress: string
): Promise<bigint> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getCollateralDeposited",
    args: [vauldId],
    account: userAddress,
  });
  return data;
};

const getTcUSDAmountCanBorrow = async (
  vaultId: number,
  userAddress: string
): Promise<bigint> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getAmountCanBorrow",
    args: [vaultId],
    account: userAddress,
  });
  return data;
};

const getAllPostionExists = async (owner: string): Promise<number[] | null> => {
  try {
    const data = await readContract({
      ...(engineContract as any),
      functionName: "getAllPositionExists",
      args: [owner],
    });
    return data as number[];
  } catch (error) {
    console.log(error);
    return null;
  }
};

const getUniquePosition = async (
  positionId: number,
  userAddress: string
): Promise<any> => {
  try {
    const data = await readContract({
      ...(engineContract as any),
      functionName: "getUniquePosition",
      args: [positionId],
      account: userAddress,
    });
    return data;
  } catch (error) {
    console.log(error);
    return null;
  }
};

// ===== Write contract
const depositCollateral = async (
  vaultId: number,
  amountToDeposit: bigint,
  userAddress: string
): Promise<string | null> => {
  try {
    const { hash } = await writeContract({
      ...(engineContract as any),
      functionName: "depositCollateral",
      args: [vaultId, Number(amountToDeposit) - 100000000],
      account: userAddress,
    });
    return hash.toString();
  } catch (error) {
    console.log(error);
    return null;
  }
};

const createPosition = async (
  vaultId: number,
  amountCollateral: number,
  amountBorrow: number,
  userAddress: string
): Promise<string | null> => {
  try {
    const { hash } = await writeContract({
      ...(engineContract as any),
      functionName: "createPosition",
      args: [vaultId, amountCollateral - 100000000, amountBorrow - 100000000],
      account: userAddress,
    });
    return hash.toString();
  } catch (error) {
    console.log(error);
    return null;
  }
};

const canclePosition = async (
  positionId: number,
  userAddress: string
): Promise<string | null> => {
  try {
    const { hash } = await writeContract({
      ...(engineContract as any),
      functionName: "cancelPosition",
      args: [positionId],
      account: userAddress,
    });
    return hash.toString();
  } catch (error) {
    console.log(error);
    return null;
  }
};

export {
  engineContract,
  getCurrentVaultId,
  getVaultAddress,
  getVaultBalance,
  getUSDValueOfCollateral,
  getUserVaultBalance,
  getTcUSDAmountCanBorrow,
  depositCollateral,
  createPosition,
  getAllPostionExists,
  getUniquePosition,
  canclePosition,
};

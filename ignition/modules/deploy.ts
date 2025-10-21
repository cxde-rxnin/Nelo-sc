import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const wrappedNative = process.env.WRAPPED_NATIVE_ADDRESS!;
const admin = process.env.ADMIN_ADDRESS!;

const Nelo = buildModule("Nelo", (m) => {
  const nelo = m.contract("Nelo", [wrappedNative, admin]);
  return { nelo };
});

export default Nelo;

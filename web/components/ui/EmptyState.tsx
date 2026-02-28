type Props = { message: string };

export function EmptyState({ message }: Props) {
  return (
    <div
      style={{
        padding: "calc(var(--spacing-2xl) * 2) var(--spacing-xl)",
        textAlign: "center",
        color: "var(--color-gray-500)",
        fontSize: "var(--font-size-base)",
      }}
    >
      {message}
    </div>
  );
}

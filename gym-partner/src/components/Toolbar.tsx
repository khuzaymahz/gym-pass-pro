import type { ReactNode } from "react";

export function Toolbar({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="toolbar-inline">
      <div>
        <h1 className="h1">{title}</h1>
        {description ? (
          <p className="mt-0.5 text-[12.5px] text-muted">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </div>
  );
}

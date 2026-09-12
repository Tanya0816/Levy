import type { ReactNode } from 'react';
export function GlassCard({children,padding='md',tone='default'}:{children:ReactNode;padding?:'sm'|'md';tone?:'default'|'accent'}){
 return <section className={`glass ${padding==='sm'?'glass-sm':''} ${tone==='accent'?'glass-accent':''}`}>{children}</section>;
}
export function CardHeading({title,subtitle,action}:{title:string;subtitle?:string;action?:ReactNode}){
 return <div className="card-heading"><div><h2>{title}</h2>{subtitle&&<p>{subtitle}</p>}</div>{action}</div>;
}

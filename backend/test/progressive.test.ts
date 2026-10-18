import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import { answerPassages } from '../src/progressive.js';
import { Providers } from '../src/providers.js';
import { readConfig } from '../src/config.js';
test('progressive passages preserve all words and do not split abbreviations or short answers',()=>{
 const text='Dr. Smith explains the finding in a short opening sentence. The rest adds enough clear context for a listener to understand what the researchers found and why it matters.';
 const parts=answerPassages(text);assert.equal(parts.length,2);assert.ok(parts[0]!.length>4);
 assert.equal(parts.join(' ').replace(/\s+/g,' '),text);
 assert.deepEqual(answerPassages('Yes. It is a proposal.'),['Yes. It is a proposal.']);
});
test('Luna routing disables extra reasoning and carries delivery with no separate direction call',async()=>{
 const config=readConfig({SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'test-only-secret-key',OPENAI_API_KEY:'test-only-openai',ELEVENLABS_API_KEY:'test-only-eleven',ELEVENLABS_VOICE_ID:'testvoice',OPENAI_ANSWER_MODEL:'gpt-6-luna'});
 let calls=0;const fetch=mock.method(globalThis,'fetch',async(_url:any,opts:any)=>{
  calls++;const body=JSON.parse(opts.body);assert.equal(body.model,'gpt-6-luna');assert.equal(body.reasoning.effort,'none');
  return Response.json({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify({route:'general',title:'Explanation',summary:'An explanation.',category:'science',script:'Light bends as it enters a raindrop.',sourceURLs:[],tone:'curious'})}]}]});
 });
 const p=new Providers(config);const speech=mock.method(p,'speech',async(text:string)=>{assert.match(text,/\[curious\]/);return {audio:Buffer.from('audio'),duration:2};});
 try{const a=await p.answer('How do rainbows form?','',new AbortController().signal);await p.expressiveSpeech(a.script,'eleven_v4_turbo',new AbortController().signal,a.tone);assert.equal(calls,1);}finally{fetch.mock.restore();speech.mock.restore();}
});

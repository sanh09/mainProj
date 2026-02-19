import os

from api_call_counter import ApiCallCounter


def _get_client():
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise RuntimeError(
            "openai 패키지가 없습니다. `pip install openai`로 설치하세요."
        ) from exc
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("환경 변수에 OPENAI_API_KEY가 설정되어 있지 않습니다.")
    return OpenAI(api_key=api_key)


def chat_completion(
    prompt: str,
    model: str = "gpt-5.2",
    system_prompt: str | None = None,
    max_tokens: int | None = None,
) -> str:
    client = _get_client()
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})
    if max_tokens is None:
        max_tokens = int(os.getenv("OPENAI_MAX_TOKENS", "1200"))
    ApiCallCounter.record_current(f"openai_chat:{model}")
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        max_completion_tokens=max_tokens,
    )
    content = response.choices[0].message.content or ""
    if os.getenv("LOG_LLM_TOKENS", "false").lower() in ("1", "true", "yes", "y"):
        input_chars = sum(len(m.get("content") or "") for m in messages)
        output_chars = len(content)
        approx_tokens = (input_chars + output_chars) // 4
        print(
            "[LLM TOKENS approx] "
            f"label=chat_completion model={model} input_chars={input_chars} output_chars={output_chars} "
            f"approx_tokens={approx_tokens}"
        )
    return content

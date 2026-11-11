from pathlib import Path
from xml.sax.saxutils import escape
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/pdf/math_trainer_sellable_mvp.pdf'
OUT.parent.mkdir(parents=True,exist_ok=True)
pdfmetrics.registerFont(TTFont('Text',r'C:\Windows\Fonts\calibri.ttf'))
pdfmetrics.registerFont(TTFont('TextBold',r'C:\Windows\Fonts\calibrib.ttf'))
pdfmetrics.registerFontFamily('Text',normal='Text',bold='TextBold')
navy=colors.HexColor('#17324D'); teal=colors.HexColor('#147D85'); ink=colors.HexColor('#263746'); pale=colors.HexColor('#EFF5F8'); line=colors.HexColor('#D7E3EA')
W,H=A4; width=W-96
body=ParagraphStyle('Body',fontName='Text',fontSize=11.3,leading=15.3,textColor=ink,spaceAfter=9)
head=ParagraphStyle('Head',parent=body,fontName='TextBold',fontSize=14,leading=18,textColor=navy,spaceBefore=13,spaceAfter=7,keepWithNext=True)
cell=ParagraphStyle('Cell',parent=body,fontSize=10.6,leading=14,spaceAfter=0)
cellhead=ParagraphStyle('CellHead',parent=cell,fontName='TextBold',textColor=colors.white)
def P(t,style=body):return Paragraph(t,style)
story=[]
story.append(P('МАТЕМАТИЧЕСКИЙ ТРЕНАЖЁР',ParagraphStyle('Label',parent=body,fontName='TextBold',fontSize=9.5,textColor=teal,spaceAfter=13)))
story.append(P('MVP, который можно продавать',ParagraphStyle('Title',parent=head,fontSize=25,leading=29,spaceBefore=0,spaceAfter=13)))
story.append(P('Рабочее определение и выбор первого покупателя',ParagraphStyle('Subtitle',parent=body,fontSize=12,textColor=teal,spaceAfter=15)))
story.append(P('<b>MVP здесь - минимальная версия, которую уже можно предложить за деньги:</b> с понятным покупателем, обещанием пользы и достаточным качеством исполнения.'))
story.append(P('Сначала нужно выбрать, <b>кому и за что продаём</b>. От этого зависит обязательный состав первой версии.'))
story.append(P('Три возможных продукта',head))
rows=[['Покупатель','Возможный платный продукт'],['Родитель или ученик','Доступ к тренажёру по ограниченному набору тем с объяснениями, практикой и сохранением прогресса.'],['Учитель','Инструмент подготовки разных вариантов заданий и проверочных работ с ответами, дополненный практикой.'],['Школа или учебный центр','Организация практики для группы с получением результатов преподавателем.']]
t=Table([[P(escape(c),cellhead if i==0 else cell) for c in row] for i,row in enumerate(rows)],colWidths=[148,width-148])
t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),navy),('ROWBACKGROUNDS',(0,1),(-1,-1),[pale,colors.white]),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),11),('RIGHTPADDING',(0,0),(-1,-1),11),('TOPPADDING',(0,0),(-1,-1),10),('BOTTOMPADDING',(0,0),(-1,-1),10),('LINEBELOW',(0,1),(-1,-1),0.4,line)]))
story.extend([t,Spacer(1,10)])
story.append(P('Это три разных состава MVP. Учителю может быть достаточно качественного генератора материалов, а школе потребуется организация работы с несколькими учениками.'))
story.append(P('Обязателен весь путь покупателя',head))
story.append(P('<b>Понять предложение → купить → получить доступ → воспользоваться продуктом → получить обещанную пользу → обратиться за помощью.</b>'))
story.append(P('На первых продажах оплату, выдачу доступа и поддержку можно организовать вручную.'))
story.append(P('Что рассматриваем первым',head))
story.append(P('С учётом уже сделанного стоит рассмотреть два ближайших варианта: <b>инструмент для учителя</b> или <b>тренажёр для ученика по конкретному разделу</b>. Выбор зависит от того, какой продукт владелец хочет продавать первым.'))
q=Table([[P('<b>Главный открытый вопрос</b><br/>Кто наш первый покупатель: учитель или родитель / ученик?',ParagraphStyle('Question',parent=body,fontSize=12,leading=17,spaceAfter=0))]],colWidths=[width])
q.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),pale),('BOX',(0,0),(-1,-1),0.5,line),('LEFTPADDING',(0,0),(-1,-1),13),('RIGHTPADDING',(0,0),(-1,-1),13),('TOPPADDING',(0,0),(-1,-1),11),('BOTTOMPADDING',(0,0),(-1,-1),11)]))
story.extend([Spacer(1,4),q])
def page(c,d):
 c.saveState();c.setStrokeColor(line);c.line(48,40,W-48,40);c.setFillColor(colors.HexColor('#596B7C'));c.setFont('Text',8.5);c.drawString(48,26,'Материал для обсуждения. Покупатель и состав MVP ещё не выбраны.');c.drawRightString(W-48,26,str(d.page));c.restoreState()
doc=SimpleDocTemplate(str(OUT),pagesize=A4,leftMargin=48,rightMargin=48,topMargin=38,bottomMargin=53,title='Математический тренажёр: продаваемый MVP',author='Проект math_trainer')
doc.build(story,onFirstPage=page,onLaterPages=page)
print(OUT)
